//
//  Todo.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 5/11/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import struct Foundation.UUID
import struct Foundation.Date

enum SyncState {
    case syncing
    case success
    case failed(Error)
}

struct Task {
    let id: UUID
    let created: Date
    var title: String
    var isCompleted: Bool
    var isArchived: Bool // we never delete anything ;)
    var state: SyncState

    static func create(title: String, date: Date) -> Task {
        return Task(id: UUID(), created: date, title: title, isCompleted: false, isArchived: false, state: .syncing)
    }
}

struct Todo {
    enum Event {
        case created(Version<Task>)
        case toggleCompleted(Version<Task>)
        case archive(Version<Task>)
        
        case synchronizationChanged(Version<Task>, SyncState)

        case toggleEditingMode
    }

    var tasks: Storage<Version<Task>> = Storage()

    var isEditing: Bool = false
}

extension Todo {
    static func reduce(state: Todo, event: Event) -> Todo {
        switch event {
        case .created(let task):
            return state.map(task: task, transform: Version<Task>.mutate { _ in })
        case .toggleCompleted(let task):
            return state.map(task: task, transform: Version<Task>.mutate { $0.isCompleted = !$0.isCompleted })
        case .archive(let task):
            return state.map(task: task, transform: Version<Task>.mutate { $0.isArchived = true })
        case .synchronizationChanged(let task, let synchronizationState):
            return state.map(task: task, transform: Version<Task>.mutate { $0.state = synchronizationState })
        case .toggleEditingMode:
            return state.map { $0.isEditing = !$0.isEditing }
        }
    }
}

extension Todo {
    static func `for`(tasks: [Task]) -> Todo {
        return tasks.reduce(Todo()) { (all, task) in Todo.reduce(state: all, event: .created(Version(task)))  }
    }
}

// queries
extension Todo {
    var tasksByDate: [Version<Task>] {
        return self.tasks
            .sorted(key: { $0.value.created })
    }
    var completedTasks: [Version<Task>] {
        return tasksByDate
            .filter { $0.value.isCompleted && !$0.value.isArchived }
    }
    var unfinishedTasks: [Version<Task>] {
        return tasksByDate
            .filter { !$0.value.isCompleted && !$0.value.isArchived }
    }
    var tasksToSynchronize: Set<Version<Task>> {
        return Set(self.tasksByDate.filter { $0.value.needsSynchronization }.prefix(1))
    }
}

extension Task {
    var needsSynchronization: Bool {
        if case .syncing = self.state {
            return true
        }
        return false
    }
}


