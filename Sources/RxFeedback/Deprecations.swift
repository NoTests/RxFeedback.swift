//
//  Deprecations.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 8/13/17.
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
@available(*, deprecated, message: "Renamed to version that takes `ObservableSchedulerContext` as argument.", renamed: "react(query:effects:)")
public func react<State, Control: Equatable, Event>(
    query: @escaping (State) -> Control?,
    effects: @escaping (Control) -> Observable<Event>
) -> (Observable<State>) -> Observable<Event> {
    return { state in
        let context = ObservableSchedulerContext(source: state, scheduler: CurrentThreadScheduler.instance)
        return react(query: query, effects: effects)(context)
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
@available(*, deprecated, message: "Renamed to version that takes `ObservableSchedulerContext` as argument.", renamed: "react(query:effects:)")
public func react<State, Control, Event>(
    query: @escaping (State) -> Control?,
    effects: @escaping (Control) -> Observable<Event>
    ) -> (Observable<State>) -> Observable<Event> {
    return { state in
        let context = ObservableSchedulerContext(source: state, scheduler: CurrentThreadScheduler.instance)
        return react(query: query, effects: effects)(context)
    }
}

extension ObservableType where E == Any {
    /**
     Simulation of a discrete system (finite-state machine) with feedback loops.
     Interpretations:
     - [system with feedback loops](https://en.wikipedia.org/wiki/Control_theory)
     - [fixpoint solver](https://en.wikipedia.org/wiki/Fixed_point)
     - [local equilibrium point calculator](https://en.wikipedia.org/wiki/Mechanical_equilibrium)
     - ....

     System simulation will be started upon subscription and stopped after subscription is disposed.

     System state is represented as a `State` parameter.
     Events are represented by `Event` parameter.

     - parameter initialState: Initial state of the system.
     - parameter accumulator: Calculates new system state from existing state and a transition event (system integrator, reducer).
     - parameter feedback: Feedback loops that produce events depending on current system state.
     - returns: Current state of the system.
     */
    @available(*, deprecated, message: "Renamed to version that takes `ObservableSchedulerContext` as argument.", renamed: "system(initialState:reduce:scheduler:scheduledFeedback:)")
    public static func system<State, Event>(
        initialState: State,
        reduce: @escaping (State, Event) -> State,
        scheduler: ImmediateSchedulerType,
        feedback: [(Observable<State>) -> Observable<Event>]
        ) -> Observable<State> {
        let observableFeedbacks: [(ObservableSchedulerContext<State>) -> Observable<Event>] = feedback.map { feedback in
            return { sourceSchedulerContext in
                return feedback(sourceSchedulerContext.source)
            }
        }

        return Observable<Any>.system(
                initialState: initialState,
                reduce: reduce,
                scheduler: scheduler,
                scheduledFeedback: observableFeedbacks
            )
    }

    @available(*, deprecated, message: "Renamed to version that takes `ObservableSchedulerContext` as argument.", renamed: "system(initialState:reduce:scheduler:scheduledFeedback:)")
    public static func system<State, Event>(
        initialState: State,
        reduce: @escaping (State, Event) -> State,
        scheduler: ImmediateSchedulerType,
        feedback: (Observable<State>) -> Observable<Event>...
    ) -> Observable<State> {
        return system(initialState: initialState, reduce: reduce, scheduler: scheduler, feedback: feedback)
    }
}

