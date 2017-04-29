//
//  FeedbackLoops.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 5/1/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import RxSwift
import RxCocoa

/**
 Control feedback loop that tries to immediatelly perform the latest required effect.

 * State: State type of the system.
 * Control: Subset of state used to control the feedback loop.
 
 When query result exists (not `nil`), feedback loop is active and it performs events.
 
 When query result is `nil`, feedback loops doesn't perform any effect.

 - parameter query: State type of the system
 - parameter effects: Control state which is subset of state.
 - returns: Feedback loop performing the effects.
 */
public func react<State, Control: Equatable, Event>(
    query: @escaping (State) -> Control?,
    effects: @escaping (Control) -> Observable<Event>
) -> (Observable<State>) -> Observable<Event> {
    return { state in
        return state.map(query)
            .distinctUntilChanged { $0 == $1 }
            .flatMapLatest { (results: Control?) -> Observable<Event> in
                guard let results = results else {
                    return Observable<Event>.empty()
                }

                return effects(results)
            }
    }
}

/**
 Control feedback loop that tries to immediatelly perform the latest required effect.

 * State: State type of the system.
 * Control: Subset of state used to control the feedback loop.

 When query result exists (not `nil`), feedback loop is active and it performs events.

 When query result is `nil`, feedback loops doesn't perform any effect.

 - parameter query: State type of the system
 - parameter effects: Control state which is subset of state.
 - returns: Feedback loop performing the effects.
 */
public func react<State, Control: Equatable, Event>(
    query: @escaping (State) -> Control?,
    effects: @escaping (Control) -> Driver<Event>
) -> (Driver<State>) -> Driver<Event> {
    return { state in
        return state.map(query)
            .distinctUntilChanged { $0 == $1 }
            .flatMapLatest { (results: Control?) -> Driver<Event> in
                guard let results = results else {
                    return Driver<Event>.empty()
                }

                return effects(results)
        }
    }
}

/**
 Control feedback loop that tries to immediatelly perform the latest required effect.

 * State: State type of the system.
 * Control: Subset of state used to control the feedback loop.

 When query result exists (not `nil`), feedback loop is active and it performs events.

 When query result is `nil`, feedback loops doesn't perform any effect.

 - parameter query: State type of the system
 - parameter effects: Control state which is subset of state.
 - returns: Feedback loop performing the effects.
 */
public func react<State, Control, Event>(
    query: @escaping (State) -> Control?,
    effects: @escaping (Control) -> Observable<Event>
) -> (Observable<State>) -> Observable<Event> {
    return { state in
        return state.map(query)
            .distinctUntilChanged { $0 != nil }
            .flatMapLatest { (results: Control?) -> Observable<Event> in
                guard let results = results else {
                    return Observable<Event>.empty()
                }

                return effects(results)
        }
    }
}

/**
 Control feedback loop that tries to immediatelly perform the latest required effect.

 * State: State type of the system.
 * Control: Subset of state used to control the feedback loop.

 When query result exists (not `nil`), feedback loop is active and it performs events.

 When query result is `nil`, feedback loops doesn't perform any effect.

 - parameter query: State type of the system
 - parameter effects: Control state which is subset of state.
 - returns: Feedback loop performing the effects.
 */
public func react<State, Control, Event>(
    query: @escaping (State) -> Control?,
    effects: @escaping (Control) -> Driver<Event>
) -> (Driver<State>) -> Driver<Event> {
    return { state in
        return state.map(query)
            .distinctUntilChanged { $0 != nil }
            .flatMapLatest { (results: Control?) -> Driver<Event> in
                guard let results = results else {
                    return Driver<Event>.empty()
                }

                return effects(results)
        }
    }
}
