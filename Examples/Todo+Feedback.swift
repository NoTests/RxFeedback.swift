//
//  Todo+Feedback.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 5/11/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import RxFeedback

extension Todo {
    typealias Feedback = (Driver<Todo>) -> Driver<Todo.Event>
    
    static func system(initialState: Todo, ui: @escaping Feedback, synchronizeTask: @escaping (Task) -> Single<SyncState>) -> Driver<Todo> {
        let synchronizeFeedback: Feedback = react(query: { $0.tasksToSynchronize }) { task -> Driver<Todo.Event> in
            return synchronizeTask(task.value)
                .map { Todo.Event.synchronizationChanged(task, $0) }
                .asDriver(onErrorRecover: { error in Driver.just(.synchronizationChanged(task, .failed(error))) })
        }
        
        return Driver<Any>.system(initialState: initialState,
                                  reduce: Todo.reduce,
                                  feedback: ui, synchronizeFeedback)
    }
}
