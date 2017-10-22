//
//  Todo+UI.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 5/11/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import RxFeedback

fileprivate enum Row {
    case task(Version<Task>)
    case new
}

class TodoViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView?
    @IBOutlet weak var editDone: UIBarButtonItem?

    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        // this dependency would be ideally injected in some way
        let synchronize: (Task) -> Single<SyncState> = { task in
            return Single<SyncState>.create { single in
                    let state: SingleEvent<SyncState> = arc4random_uniform(3) != 0 ? .success(.success) : .error(SystemError(""))
                    single(state)
                    return Disposables.create()
                }
                .delaySubscription(TimeInterval.random(min: 0.5, max: 2.0), scheduler: MainScheduler.instance)
        }

        let tasks = [
            Task.create(title: "Write RxSwift", date: Date()),
            Task.create(title: "Give a lecture", date: Date()),
            Task.create(title: "Enjoy", date: Date()),
            Task.create(title: "Let's stop at Enjoy", date: Date()),
        ] + (1 ... 10).map { Task.create(title: "Task \($0)", date: Date()) }

        Todo.system(
            initialState: Todo.for(tasks: tasks),
            ui: bindings, synchronizeTask: synchronize)
            .drive()
            .disposed(by: disposeBag)

        self.tableView!.rx.setDelegate(self)
            .disposed(by: disposeBag)
    }
}

extension TodoViewController {
    var bindings: Todo.Feedback {
        let bindCell: (Int, Row, UITableViewCell) -> () = { index, element, cell in
            cell.textLabel?.attributedText =  element.title
            cell.detailTextLabel?.attributedText = element.detail
        }

        let promptForTask = UIAlertController.prompt(message: "Please enter task name", title: "Adding task", actions: [AlertAction.ok, AlertAction.cancel], parent: self) { controller in
            controller.addTextField(configurationHandler: nil)
        }
            .flatMapLatest { (controller, action) -> Observable<Todo.Event> in
                guard case .ok = action else {
                    return Observable.empty()
                }
                let task = Version(Task.create(title: controller.textFields?.first?.text ?? "", date: Date()))
                return Observable.just(Todo.Event.created(task))
            }

        let tableView = self.tableView!
        let editDone = self.editDone!

        return bind { state in
            let tasks = state.map { [Row.new] + ($0.unfinishedTasks + $0.completedTasks).map(Row.task) }
            let editing = state.map { $0.isEditing }
            let editButtonTitle = editing.map { $0 ? "Done" : "Edit" }
            
            let subscriptions = [
                    tasks.drive(tableView.rx.items(cellIdentifier: "Cell"))(bindCell),
                    editing.drive(tableView.rx.isEditing),
                    editButtonTitle.drive(editDone.rx.title)
                ]
            let events = [
                    editDone.rx.tap.asSignal().map { _ in Todo.Event.toggleEditingMode },
                    
                    tableView.rx.modelSelected(Row.self).asSignal()
                        .flatMapLatest { row in row.selectedEvent(prompt: promptForTask) },
                    tableView.rx.itemDeleted.asSignal()
                        .flatMapLatest { (try! tableView.rx.model(at: $0) as Row).deletedEvent },
                    tableView.rx.itemInserted.asSignal()
                        .flatMapLatest { _ in
                            return promptForTask.asSignal(onErrorSignalWith: Signal.empty())
                        }

                ]
            return Bindings(subscriptions: subscriptions, events: events)
        }
    }
}

extension TodoViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        let row: Row = try! tableView.rx.model(at: indexPath)
        return row.editingStyle
    }
}

extension Version where Value == Task {
    var syncTitle: NSAttributedString {
        return NSAttributedString(string: {
            switch self.state {
            case .failed:
                return "🔥"
            case .success:
                return "✔️"
            case .syncing:
                return "↻"
            }
        }())
    }
    var title: NSAttributedString {
        return [self.value.title, " ", self.value.isCompleted ? " ✅" : ""].joinedAttributed(separator: "")
    }
    var detail: NSAttributedString {
        return [self.syncTitle,].joinedAttributed(separator: "")
    }
}

extension Row {
    var editingStyle: UITableViewCellEditingStyle {
        switch self {
        case .new: return .insert
        case .task: return .delete
        }
    }
    var title: NSAttributedString {
        switch self {
        case .new: return "New".attributedString
        case .task(let task): return task.title
        }
    }
    var detail: NSAttributedString {
        switch self {
        case .new: return "".attributedString
        case .task(let task): return task.detail
        }
    }

    func selectedEvent(prompt: Observable<Todo.Event>) -> Signal<Todo.Event> {
        switch self {
        case .new: return prompt.asSignal(onErrorSignalWith: Signal.empty())
        case .task(let task): return Signal.just(Todo.Event.toggleCompleted(task))
        }
    }

    var deletedEvent: Signal<Todo.Event> {
        get {
            switch self {
            case .new: return Signal.empty()
            case .task(let task): return Signal.just(Todo.Event.archive(task))
            }
        }
    }
}
