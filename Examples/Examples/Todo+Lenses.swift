//
//  Todo+Lenses.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 5/11/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

extension Task {
    static func mutate(_ mutation: @escaping (inout Task) -> ()) -> (Task) -> Task {
        return { task in
            var newTask = task
            mutation(&newTask)
            return newTask
        }
    }
}

extension Version {
    static func mutate(_ mutation: @escaping (inout Value) -> ()) -> (Version<Value>) -> Version<Value> {
        return { version in
            var value = version.value
            mutation(&value)
            return Version(value)
        }
    }
}

extension Version {
    static func map(transform: @escaping (Value) -> (Value)) -> (Version<Value>) -> Version<Value> {
        return { version in
            return Version(transform(version.value))
        }
    }
}

extension Todo {
    func map(task: Version<Task>, transform: (Version<Task>) -> Version<Task>) -> Todo {
        var todo = self
        todo.tasks = todo.tasks.mutate(entity: task, transform: transform)
        return todo
    }

    func mapAll(transform: @escaping (Version<Task>) -> Version<Task>) -> Todo {
        return self.tasks.sorted(key: { $0.value.created }).reduce(self) { (state, task) in
            return state.map(task: task, transform: transform)
        }
    }

    func map(transform: (inout Todo) -> ()) -> Todo {
        var todo = self
        transform(&todo)
        return todo
    }
}

extension Task: Syncable {
    static func setSync(_ state: SyncState) -> (Task) -> Task {
        return Task.mutate({ (task) -> () in task.state = state; return () })
    }
}
