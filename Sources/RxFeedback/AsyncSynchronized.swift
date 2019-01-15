//
//  AsyncLock.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 11/4/18.
//  Copyright © 2018 Krunoslav Zaher. All rights reserved.
//

import Foundation

internal class AsyncSynchronized<State> {
    internal typealias Mutate = (inout State) -> Void

    private let lock = NSRecursiveLock()

    /// Using array as a `Queue`.
    private var queue: [Mutate]

    private var state: State

    init(_ initialState: State) {
        self.queue = []
        self.state = initialState
    }

    internal func async(_ mutate: @escaping Mutate) {
        guard var executeMutation = self.enqueue(mutate) else {
            return
        }

        repeat {
            executeMutation(&state)
            guard let nextExecute = self.dequeue() else {
                return
            }
            executeMutation = nextExecute
        } while true
    }

    private func enqueue(_ mutate: @escaping Mutate) -> Mutate? {
        lock.lock(); defer { lock.unlock() }
        let wasEmpty = self.queue.isEmpty
        self.queue.append(mutate)
        guard wasEmpty else {
            return nil
        }
        return mutate
    }

    private func dequeue() -> Mutate? {
        lock.lock(); defer { lock.unlock() }
        _ = queue.removeFirst()
        return queue.first
    }
}
