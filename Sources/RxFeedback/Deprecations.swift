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
 
 When query result exists (not `nil`), feedback loop is active and it performs effects.
 
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

 When query result exists (not `nil`), feedback loop is active and it performs effects.

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

/**
 Control feedback loop that tries to immediatelly perform the latest required effect.

 * State: State type of the system.
 * Control: Subset of state used to control the feedback loop.

 When query result exists (not `nil`), feedback loop is active and it performs effects.

 When query result is `nil`, feedback loops doesn't perform any effect.

 - parameter query: State type of the system
 - parameter effects: Control state which is subset of state.
 - returns: Feedback loop performing the effects.
 */
@available(*, deprecated, message: "Please use version that uses feedback with this signature `Driver<State> -> Signal<Event>`")
public func react<State, Control: Equatable, Event>(
    query: @escaping (State) -> Control?,
    effects: @escaping (Control) -> Driver<Event>
) -> (Driver<State>) -> Driver<Event> {
    return { state in
        return state.map(query)
            .distinctUntilChanged { $0 == $1 }
            .flatMapLatest { (control: Control?) -> Driver<Event> in
                guard let control = control else {
                    return Driver<Event>.empty()
                }

                return effects(control)
                    .enqueue()
        }
    }
}

/**
 Control feedback loop that tries to immediatelly perform the latest required effect.

 * State: State type of the system.
 * Control: Subset of state used to control the feedback loop.

 When query result exists (not `nil`), feedback loop is active and it performs effects.

 When query result is `nil`, feedback loops doesn't perform any effect.

 - parameter query: State type of the system
 - parameter effects: Control state which is subset of state.
 - returns: Feedback loop performing the effects.
 */
@available(*, deprecated, message: "Please use version that uses feedback with this signature `Driver<State> -> Signal<Event>`")
public func react<State, Control, Event>(
    query: @escaping (State) -> Control?,
    effects: @escaping (Control) -> Driver<Event>
) -> (Driver<State>) -> Driver<Event> {
    return { state in
        return state.map(query)
            .distinctUntilChanged { $0 != nil }
            .flatMapLatest { (control: Control?) -> Driver<Event> in
                guard let control = control else {
                    return Driver<Event>.empty()
                }

                return effects(control)
                    .enqueue()
        }
    }
}

/**
 Control feedback loop that tries to immediatelly perform the latest required effect.

 * State: State type of the system.
 * Control: Subset of state used to control the feedback loop.

 When query result exists (not `nil`), feedback loop is active and it performs effects.

 When query result is `nil`, feedback loops doesn't perform any effect.

 - parameter query: State type of the system
 - parameter effects: Control state which is subset of state.
 - returns: Feedback loop performing the effects.
 */
@available(*, deprecated, message: "Please use version that uses feedback with this signature `Driver<State> -> Signal<Event>`")
public func react<State, Control, Event>(
    query: @escaping (State) -> Set<Control>,
    effects: @escaping (Control) -> Driver<Event>
    ) -> (Driver<State>) -> Driver<Event> {
    return { state in
        let query = state.map(query)

        let newQueries = Driver.zip(query, query.startWith(Set())) { $0.subtracting($1) }

        return newQueries.flatMap { controls in
            return Driver.merge(controls.map { control -> Driver<Event> in
                return query.filter { !$0.contains(control) }
                    .map { _ in Driver<Event>.empty() }
                    .startWith(effects(control).enqueue())
                    .switchLatest()
            })
        }
    }
}

extension SharedSequence where SharingStrategy == DriverSharingStrategy {
    fileprivate func enqueue() -> Driver<Element> {
        return self.asObservable()
            // observe on is here because results should be cancelable
            .observeOn(S.scheduler.async)
            // subscribe on is here because side-effects also need to be cancelable
            // (smooths out any glitches caused by start-cancel immediatelly)
            .subscribeOn(S.scheduler.async)
            .asDriver(onErrorDriveWith: Driver.empty())
    }
}


extension SharedSequenceConvertibleType where E == Any, SharingStrategy == DriverSharingStrategy {
    /// Feedback loop
    @available(*, deprecated, message: "Please use Feedback")
    public typealias FeedbackLoop<State, Event> = (Driver<State>) -> Driver<Event>

    /**
     System simulation will be started upon subscription and stopped after subscription is disposed.

     System state is represented as a `State` parameter.
     Events are represented by `Event` parameter.

     - parameter initialState: Initial state of the system.
     - parameter accumulator: Calculates new system state from existing state and a transition event (system integrator, reducer).
     - parameter feedback: Feedback loops that produce events depending on current system state.
     - returns: Current state of the system.
     */
    @available(*, deprecated, message: "Please use version that uses feedbacks with this signature `Driver<State> -> Signal<Event>`")
    public static func system<State, Event>(
            initialState: State,
            reduce: @escaping (State, Event) -> State,
            feedback: [FeedbackLoop<State, Event>]
        ) -> Driver<State> {
        let observableFeedbacks: [(ObservableSchedulerContext<State>) -> Observable<Event>] = feedback.map { feedback in
            return { sharedSequence in
                return feedback(sharedSequence.source.asDriver(onErrorDriveWith: Driver<State>.empty()))
                    .asObservable()
            }
        }

        return Observable<Any>.system(
                initialState: initialState,
                reduce: reduce,
                scheduler: SharingStrategy.scheduler,
                scheduledFeedback: observableFeedbacks
            )
            .asDriver(onErrorDriveWith: .empty())
    }

    @available(*, deprecated, message: "Please use version that uses feedback with this signature `Driver<State> -> Signal<Event>`")
    public static func system<State, Event>(
            initialState: State,
            reduce: @escaping (State, Event) -> State,
            feedback: FeedbackLoop<State, Event>...
        ) -> Driver<State> {
        return system(initialState: initialState, reduce: reduce, feedback: feedback)
    }
}

@available(*, deprecated, message: "Please use free members from RxFeedback module (`RxFeedback.Bindings`, `RxFeedback.bind`, ...).")
public struct UI {
    /**
     Contains subscriptions and events.
     - `subscriptions` map a system state to UI presentation.
     - `events` map events from UI to events of a given system.
    */
    public class Bindings<Event>: Disposable {
        fileprivate let subscriptions: [Disposable]
        fileprivate let events: [Observable<Event>]

        /**
         - parameters:
            - subscriptions: mappings of a system state to UI presentation.
            - events: mappings of events from UI to events of a given system
         */
        public init(subscriptions: [Disposable], events: [Observable<Event>]) {
            self.subscriptions = subscriptions
            self.events = events
        }

        /**
         - parameters:
            - subscriptions: mappings of a system state to UI presentation.
            - events: mappings of events from UI to events of a given system
         */
        public init(subscriptions: [Disposable], events: [Driver<Event>]) {
            self.subscriptions = subscriptions
            self.events = events.map { $0.asObservable() }
        }

        public func dispose() {
            for subscription in subscriptions {
                subscription.dispose()
            }
        }
    }

    /**
     Bi-directional binding of a system State to UI and UI into Events.
     */
    public static func bind<State, Event>(_ bindings: @escaping (ObservableSchedulerContext<State>) -> (Bindings<Event>)) -> (ObservableSchedulerContext<State>) -> Observable<Event> {

        return { (state: ObservableSchedulerContext<State>) -> Observable<Event> in
            return Observable<Event>.using({ () -> Bindings<Event> in
                return bindings(state)
            }, observableFactory: { (bindings: Bindings<Event>) -> Observable<Event> in
                return Observable<Event>.merge(bindings.events)
                    .enqueue(state.scheduler)
            })
        }
    }

    /**
     Bi-directional binding of a system State to UI and UI into Events,
     Strongify owner.
     */
    public static func bind<State, Event, WeakOwner>(_ owner: WeakOwner, _ bindings: @escaping (WeakOwner, ObservableSchedulerContext<State>) -> (Bindings<Event>))
        -> (ObservableSchedulerContext<State>) -> Observable<Event> where WeakOwner: AnyObject {
            return bind(bindingsStrongify(owner, bindings))
    }

    /**
     Bi-directional binding of a system State to UI and UI into Events.
     */
    public static func bind<State, Event>(_ bindings: @escaping (Driver<State>) -> (Bindings<Event>)) -> (Driver<State>) -> Driver<Event> {

        return { (state: Driver<State>) -> Driver<Event> in
            return Observable<Event>.using({ () -> Bindings<Event> in
                return bindings(state)
            }, observableFactory: { (bindings: Bindings<Event>) -> Observable<Event> in
                return Observable<Event>.merge(bindings.events)
            }).asDriver(onErrorDriveWith: Driver.empty())
                .enqueue()
        }
    }

    /**
     Bi-directional binding of a system State to UI and UI into Events,
     Strongify owner.
     */
    public static func bind<State, Event, WeakOwner>(_ owner: WeakOwner, _ bindings: @escaping (WeakOwner, Driver<State>) -> (Bindings<Event>))
        -> (Driver<State>) -> Driver<Event> where WeakOwner: AnyObject {
            return bind(bindingsStrongify(owner, bindings))
    }

    private static func bindingsStrongify<Event, O, WeakOwner>(_ owner: WeakOwner, _ bindings: @escaping (WeakOwner, O) -> (Bindings<Event>))
        -> (O) -> (Bindings<Event>) where WeakOwner: AnyObject {
            return { [weak owner] state -> Bindings<Event> in
                guard let strongOwner = owner else {
                    return Bindings(subscriptions: [], events: [Observable<Event>]())
                }
                return bindings(strongOwner, state)
            }
    }

}

extension Observable {
    fileprivate func enqueue(_ scheduler: ImmediateSchedulerType) -> Observable<Element> {
        return self
            // observe on is here because results should be cancelable
            .observeOn(scheduler)
            // subscribe on is here because side-effects also need to be cancelable
            // (smooths out any glitches caused by start-cancel immediatelly)
            .subscribeOn(scheduler)
    }
}
