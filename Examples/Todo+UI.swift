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

        let synchronize: (Task) -> Single<SyncState> = { task in
            return Single.just(arc4random_uniform(3) != 0 ? .success : .failed(SystemError("")))
                .delaySubscription(TimeInterval(arc4random_uniform(3)) / 3.0 * 2.0, scheduler: MainScheduler.instance)
                .debug()
        }

        let tasks = [
            Task.create(title: "Write RxSwift", date: Date()),
            Task.create(title: "Give a lecture", date: Date()),
            Task.create(title: "Enjoy", date: Date()),
            Task.create(title: "Let's stop at Enjoy", date: Date()),
        ]

        Todo.system(
            initialState: Todo.for(tasks: tasks),
            ui: bindings, synchronizeTask: synchronize)
            .drive()
            .disposed(by: disposeBag)

        self.tableView!.rx.setDelegate(self)
            .disposed(by: disposeBag)
    }

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

        return UI.bind { state in
            let tasks = state.map { [Row.new] + ($0.unfinishedTasks + $0.completedTasks).map(Row.task) }
            let editing = state.map { $0.isEditing }
            
            return ([
                    tasks.drive(self.tableView!.rx.items(cellIdentifier: "Cell"))(bindCell),
                    editing.drive(onNext: { tableView.isEditing = $0 }),
                    editing.map { $0 ? "Done" : "Edit" }.drive(editDone.rx.title)
                ],
                [
                    editDone.rx.tap.asDriver().map { _ in Todo.Event.toggleEditingMode },
                    
                    tableView.rx.modelSelected(Row.self).asDriver()
                        .flatMapLatest { row in row.selectedEvent(prompt: promptForTask) },
                    tableView.rx.itemDeleted.asDriver()
                        .flatMapLatest { (try! tableView.rx.model(at: $0) as Row).deletedEvent },
                    tableView.rx.itemInserted.asDriver()
                        .flatMapLatest { _ in
                            return promptForTask.asDriver(onErrorDriveWith: Driver.empty())
                        }

                ])
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

    func selectedEvent(prompt: Observable<Todo.Event>) -> Driver<Todo.Event> {
        switch self {
        case .new: return prompt.asDriver(onErrorDriveWith: Driver.empty())
        case .task(let task): return Driver.just(Todo.Event.toggleCompleted(task))
        }
    }

    var deletedEvent: Driver<Todo.Event> {
        get {
            switch self {
            case .new: return Driver.empty()
            case .task(let task): return Driver.just(Todo.Event.archive(task))
            }
        }
    }
}
