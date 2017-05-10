import RxSwift
import RxCocoa
import RxFeedback

public enum OAuthResponse<Payload> {
    case success(Payload)
    case tokenInvalidated
}

public enum TokenState<Token: Equatable> {
    case fresh(Version<Token>)
    case refreshing(Version<Token>)
    case refreshFailed(Version<Token>, lastError: Error)
    case tokenInvalidated(Version<Token>)
}

public enum Event<Token> {
    case refresh(Version<Token>)
    case tokenRefreshed(SingleEvent<OAuthResponse<Token>>)
}

extension TokenState {
    static func reduce(state: TokenState<Token>, event: Event<Token>) -> TokenState<Token> {
        switch event {
        case .refresh(let version):
            switch state {
            case .tokenInvalidated:
                return state
            default:
                if version == state.token {
                    return .refreshing(version)
                }
            }
        case .tokenRefreshed(.success(.success(let token))):
            return .fresh(Version(token))
        case .tokenRefreshed(.success(.tokenInvalidated)):
            return .tokenInvalidated(Version(state.token.value))
        case .tokenRefreshed(.error(let error)):
            return .refreshFailed(Version(state.token.value), lastError: error)
        }

        return state
    }
}

public enum OAuth<Token: Equatable> {
    public typealias Feedback = (Driver<TokenState<Token>>) -> Driver<Event<Token>>

    /**
     Implementation of OAuth feedback loops when using external persistent token storage.

     e.g. Token is stored in database.
    */
    public static func feedback(
        refreshToken: @escaping (Token) -> Single<OAuthResponse<Token>>,
        shouldRefreshNow: @escaping (Token) -> Bool,
        authenticated: @escaping (OAuthExecutor<Token>) -> ()
    ) -> Feedback {
        let initiateRefreshProcessFeedback: Feedback = { state in
            let invalidTokenEvent = PublishSubject<Event<Token>>()
            let refreshTokenNow: (Version<Token>) -> () = { (token) in invalidTokenEvent.on(.next(.refresh(token))) }

            authenticated(OAuthExecutor(state: state, refreshToken: refreshTokenNow, shouldRefreshNow: shouldRefreshNow))

            return invalidTokenEvent.asDriver(onErrorDriveWith: Driver.empty())
        }

        let refreshProcessFeedback: Feedback = react(query: { $0.isRefreshing }, effects: { token in
            refreshToken(token.value)
                .map { Event<Token>.tokenRefreshed(.success($0)) }
                .asDriver(onErrorRecover: { Driver.just(Event<Token>.tokenRefreshed(SingleEvent.error($0))) })
        })

        return { state in
            return Driver.merge(initiateRefreshProcessFeedback(state), refreshProcessFeedback(state))
        }
    }

    /**
     Implementation of OAuth feedback loops with in memory token storage and optional mirroring of that state
     in some external persistent storage by using `OAuthExecutor.state`.
    */
    public static func system(
        initialToken: Token,
        refreshToken: @escaping (Token) -> Single<OAuthResponse<Token>>,
        shouldRefreshNow: @escaping (Token) -> Bool = { _ in false }
    ) -> Observable<OAuthExecutor<Token>> {
        return Observable.create { observer in
            let system = Driver.system(
                initialState: .fresh(Version(initialToken)), reduce: TokenState.reduce,
                feedback: feedback(
                    refreshToken: refreshToken,
                    shouldRefreshNow: shouldRefreshNow,
                    authenticated: { observer.on(.next($0)) }
                )
            )

            return system.drive()
        }
    }
}

extension TokenState {
    var isRefreshing: Version<Token>? {
        if case let .refreshing(version) = self {
            return version
        }
        return nil
    }

    var token: Version<Token> {
        switch self {
        case let .fresh(version):
            return version
        case let .refreshing(version):
            return version
        case let .refreshFailed(version, _):
            return version
        case let .tokenInvalidated(version):
            return version
        }
    }
}

public struct OAuthExecutor<Token: Equatable> {
    public let state: Driver<TokenState<Token>>
    
    fileprivate let refreshToken: (Version<Token>) -> ()
    fileprivate let shouldRefreshNow: (Token) -> Bool

    fileprivate init(state: Driver<TokenState<Token>>, refreshToken: @escaping (Version<Token>) -> (), shouldRefreshNow: @escaping (Token) -> Bool) {
        self.state = state
        self.refreshToken = refreshToken
        self.shouldRefreshNow = shouldRefreshNow
    }

    public func authenticate<Payload>(request: @escaping (Single<Token>) -> Single<OAuthResponse<Payload>>) -> Single<OAuthResponse<Payload>> {
        func makeAuthenticatedRequest(token: Version<Token>, canRefresh: Bool) -> Single<OAuthResponse<Payload>> {
            return request(Single.just(token.value)).flatMap { result in
                switch result {
                case .success:
                    return Single.just(result)
                case .tokenInvalidated:
                    if !canRefresh {
                        return Single.just(.tokenInvalidated)
                    }
                    return refreshAndTryToFetchNew(invalidToken: token)
                }
            }
        }

        func refreshAndTryToFetchNew(invalidToken: Version<Token>) -> Single<OAuthResponse<Payload>> {
            return self.state.asObservable()
                .filter { !($0.token == invalidToken) }
                .do(onSubscribed: {
                    self.refreshToken(invalidToken)
                })
                .take(1)
                .asSingle()
                .flatMap { currentState in
                    switch currentState {
                    case let .fresh(version):
                        return makeAuthenticatedRequest(token: version, canRefresh: false)
                    case .refreshing:
                        return Single.just(.tokenInvalidated)
                    case let .refreshFailed(_, error):
                        return Single.error(error)
                    case .tokenInvalidated:
                        return Single.just(.tokenInvalidated)
                    }
            }
        }

        return state.asObservable()
            .flatMapLatest { state -> Observable<Single<OAuthResponse<Payload>>> in
                switch state {
                case let .fresh(version):
                    if self.shouldRefreshNow(version.value) {
                        return Observable.just(refreshAndTryToFetchNew(invalidToken: version))
                    }
                    return Observable.just(makeAuthenticatedRequest(token: version, canRefresh: true))
                case .refreshing(_):
                    return Observable.empty()
                case let .refreshFailed(version, _):
                    return Observable.just(refreshAndTryToFetchNew(invalidToken: version))
                case .tokenInvalidated:
                    return Observable.just(Single.just(.tokenInvalidated))
                }
            }
            .take(1)
            .asSingle()
            .flatMap { $0 }

        }
}
