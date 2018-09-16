//
//  GithubPaginatedSearch.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 5/1/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import RxFeedback

fileprivate struct Repository {
    var name: String
    var url: URL
    
    init(name: String, url: URL) {
        self.name = name
        self.url = url
    }
}

fileprivate struct State {
    var search: String {
        didSet {
            if search.isEmpty {
                self.nextPageURL = nil
                self.shouldLoadNextPage = false
                self.results = []
                self.lastError = nil
                return
            }
            self.nextPageURL = URL(string: "https://api.github.com/search/repositories?q=\(search.URLEscaped)")
            self.shouldLoadNextPage = true
            self.lastError = nil
        }
    }
    
    var nextPageURL: URL?
    var shouldLoadNextPage: Bool
    var results: [Repository]
    var lastError: GitHubServiceError?
}

fileprivate enum Mutation {
    case searchChanged(String)
    case response(SearchRepositoriesResponse)
    case startLoadingNextPage
}

// transitions
extension State {
    static var empty: State {
        return State(search: "", nextPageURL: nil, shouldLoadNextPage: true, results: [], lastError: nil)
    }

    static func reduce(state: State, mutation: Mutation) -> State {
        switch mutation {
        case .searchChanged(let search):
            var result = state
            result.search = search
            result.results = []
            return result
        case .startLoadingNextPage:
            var result = state
            result.shouldLoadNextPage = true
            return result
        case .response(.success(let response)):
            var result = state
            result.results += response.repositories
            result.shouldLoadNextPage = false
            result.nextPageURL = response.nextURL
            result.lastError = nil
            return result
        case .response(.failure(let error)):
            var result = state
            result.shouldLoadNextPage = false
            result.lastError = error
            return result
        }
    }
}

// queries
extension State {
    var loadNextPage: URL? {
        return self.shouldLoadNextPage ? self.nextPageURL : nil
    }
}

class GithubPaginatedSearchViewController: UIViewController {
    @IBOutlet weak var searchText: UISearchBar?
    @IBOutlet weak var searchResults: UITableView?
    @IBOutlet weak var status: UILabel?
    @IBOutlet weak var loadNextPage: UILabel?
    
    private let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let searchResults = self.searchResults!

        let configureCell = { (tableView: UITableView, row: Int, repository: Repository) -> UITableViewCell in
            let cell = tableView.dequeueReusableCell(withIdentifier: "RepositoryCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "RepositoryCell")

            cell.textLabel?.text = repository.name
            cell.detailTextLabel?.text = repository.url.description
            return cell
        }

        let triggerLoadNextPage: (Driver<State>) -> Signal<Mutation> = { state in
            return state.flatMapLatest { state -> Signal<Mutation> in
                if state.shouldLoadNextPage {
                    return Signal.empty()
                }
                
                return searchResults.rx.nearBottom.map { _ in Mutation.startLoadingNextPage }
            }
        }

        let bindUI: (Driver<State>) -> Signal<Mutation> = bind(self) { me, state in
            let subscriptions = [
                state.map { $0.search }.drive(me.searchText!.rx.text),
                state.map { $0.lastError?.displayMessage }.drive(me.status!.rx.textOrHide),
                state.map { $0.results }.drive(searchResults.rx.items)(configureCell),

                state.map { $0.loadNextPage?.description }.drive(me.loadNextPage!.rx.textOrHide),
                ]

            let mutations: [Signal<Mutation>] = [
                me.searchText!.rx.text.orEmpty.changed.asSignal().map(Mutation.searchChanged),
                triggerLoadNextPage(state)
            ]

            return Bindings(subscriptions: subscriptions, mutations: mutations)
        }

        Driver.system(
                initialState: State.empty,
                reduce: State.reduce,
                feedback:
                    // UI, user feedback
                    bindUI,
                    // NoUI, automatic feedback
                    react(query: { $0.loadNextPage }, effects: { resource in
                        return URLSession.shared.loadRepositories(resource: resource)
                            .asSignal(onErrorJustReturn: .failure(.offline))
                            .map(Mutation.response)
                    })
            )
            .drive()
            .disposed(by: disposeBag)
    }
}

enum Result<T, E: Error> {
    case success(T)
    case failure(E)
}

enum GitHubServiceError: Error {
    case offline
    case githubLimitReached
}

extension GitHubServiceError {
    var displayMessage: String {
        switch self {
        case .offline:
            return "Ups, no network connectivity"
        case .githubLimitReached:
            return "Reached GitHub throttle limit, wait 60 sec"
        }
    }
}


extension Repository: CustomDebugStringConvertible {
    var debugDescription: String {
        return "\(name) | \(url)"
    }
}

fileprivate typealias SearchRepositoriesResponse = Result<(repositories: [Repository], nextURL: URL?), GitHubServiceError>

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// Everything below is boring code 🙈
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

extension Reactive where Base: UITableView {
    
    var nearBottom: Signal<()> {
        func isNearBottomEdge(tableView: UITableView, edgeOffset: CGFloat = 20.0) -> Bool {
            return tableView.contentOffset.y + tableView.frame.size.height + edgeOffset > tableView.contentSize.height
        }
        
        return self.contentOffset.asDriver()
            .flatMap { _ in
                return isNearBottomEdge(tableView: self.base, edgeOffset: 20.0)
                    ? Signal.just(())
                    : Signal.empty()
        }
    }
}

extension URLSession {
    fileprivate func loadRepositories(resource: URL) -> Observable<SearchRepositoriesResponse> {
        
        // The maximum number of attempts to retry before launch the error
        let maxAttempts = 4
        
        return self
            .rx
            .response(request: URLRequest(url: resource))
            .retry(3)
            .map(Repository.parse)
            .retryWhen { errorTrigger in
                return errorTrigger.enumerated().flatMap { (attempt, error) -> Observable<Int> in
                    if attempt >= maxAttempts - 1 {
                        return Observable.error(error)
                    }
                    
                    return Observable<Int>
                        .timer(Double(attempt + 1), scheduler: MainScheduler.instance).take(1)
                }
        }
    }
}

extension Repository {
    fileprivate static func parse(httpResponse: HTTPURLResponse, data: Data) throws -> SearchRepositoriesResponse {
        if httpResponse.statusCode == 403 {
            return .failure(.githubLimitReached)
        }
        
        let jsonRoot = try Repository.parseJSON(httpResponse, data: data)
        
        guard let json = jsonRoot as? [String: AnyObject] else {
            throw SystemError("Casting to dictionary failed")
        }
        
        let repositories = try Repository.parse(json)
        
        let nextURL = try Repository.parseNextURL(httpResponse)
        
        return .success((repositories: repositories, nextURL: nextURL))
    }
    
    private static let parseLinksPattern = "\\s*,?\\s*<([^\\>]*)>\\s*;\\s*rel=\"([^\"]*)\""
    private static let linksRegex = try! NSRegularExpression(pattern: parseLinksPattern, options: [.allowCommentsAndWhitespace])
    
    private static func parse(_ json: [String: AnyObject]) throws -> [Repository] {
        guard let items = json["items"] as? [[String: AnyObject]] else {
            throw SystemError("Can't find items")
        }
        return try items.map { item in
            guard let name = item["name"] as? String,
                let url = item["url"] as? String else {
                    throw SystemError("Can't parse repository")
            }
            guard let parsedURL = URL(string: url) else {
                throw SystemError("Invalid url")
            }
            return Repository(name: name, url: parsedURL)
        }
    }
    
    private static func parseLinks(_ links: String) throws -> [String: String] {
        
        let length = (links as NSString).length
        let matches = Repository.linksRegex.matches(in: links, options: NSRegularExpression.MatchingOptions(), range: NSRange(location: 0, length: length))
        
        var result: [String: String] = [:]
        
        for m in matches {
            let matches = (1 ..< m.numberOfRanges).map { rangeIndex -> String in
                let range = m.range(at: rangeIndex)
                let startIndex = links.index(links.startIndex, offsetBy: range.location)
                let endIndex = links.index(links.startIndex, offsetBy: range.location + range.length)
                return String(links[startIndex ..< endIndex])
            }
            
            if matches.count != 2 {
                throw SystemError("Error parsing links")
            }
            
            result[matches[1]] = matches[0]
        }
        
        return result
    }
    
    private static func parseNextURL(_ httpResponse: HTTPURLResponse) throws -> URL? {
        guard let serializedLinks = httpResponse.allHeaderFields["Link"] as? String else {
            return nil
        }
        
        let links = try Repository.parseLinks(serializedLinks)
        
        guard let nextPageURL = links["next"] else {
            return nil
        }
        
        guard let nextUrl = URL(string: nextPageURL) else {
            throw SystemError("Error parsing next url `\(nextPageURL)`")
        }
        
        return nextUrl
    }
    
    private static func parseJSON(_ httpResponse: HTTPURLResponse, data: Data) throws -> AnyObject {
        if !(200 ..< 300 ~= httpResponse.statusCode) {
            throw SystemError("Call failed")
        }
        
        return try JSONSerialization.jsonObject(with: data, options: []) as AnyObject
    }
}

fileprivate extension String {
    var URLEscaped: String {
        return self.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
    }
}
