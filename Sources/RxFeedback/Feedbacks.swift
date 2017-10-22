//
//  Feedbacks.swift
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

 When query result exists (not `nil`), feedback loop is active and it performs effects.

 When query result is `nil`, feedback loops doesn't perform any effect.

 - parameter query: State type of the system
 - parameter effects: Control state which is subset of state.
 - returns: Feedback loop performing the effects.
 */
public func react<State, Control: Equatable, Event>(
        query: @escaping (State) -> Control?,
        effects: @escaping (Control) -> Observable<Event>
    ) -> (ObservableSchedulerContext<State>) -> Observable<Event> {
    return { state in
        return state.map(query)
            .distinctUntilChanged { $0 == $1 }
            .flatMapLatest { (control: Control?) -> Observable<Event> in
                guard let control = control else {
                    return Observable<Event>.empty()
                }

                return effects(control)
                    .enqueue(state.scheduler)
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
public func react<State, Control: Equatable, Event>(
    query: @escaping (State) -> Control?,
    effects: @escaping (Control) -> Signal<Event>
) -> (Driver<State>) -> Signal<Event> {
    return { state in
        return state.map(query)
            .distinctUntilChanged { $0 == $1 }
            .flatMapLatest { (control: Control?) -> Signal<Event> in
                guard let control = control else {
                    return Signal<Event>.empty()
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
public func react<State, Control, Event>(
    query: @escaping (State) -> Control?,
    effects: @escaping (Control) -> Observable<Event>
) -> (ObservableSchedulerContext<State>) -> Observable<Event> {
    return { state in
        return state.map(query)
            .distinctUntilChanged { $0 != nil }
            .flatMapLatest { (control: Control?) -> Observable<Event> in
                guard let control = control else {
                    return Observable<Event>.empty()
                }

                return effects(control)
                    .enqueue(state.scheduler)
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
public func react<State, Control, Event>(
    query: @escaping (State) -> Control?,
    effects: @escaping (Control) -> Signal<Event>
) -> (Driver<State>) -> Signal<Event> {
    return { state in
        return state.map(query)
            .distinctUntilChanged { $0 != nil }
            .flatMapLatest { (control: Control?) -> Signal<Event> in
                guard let control = control else {
                    return Signal<Event>.empty()
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
public func react<State, Control, Event>(
    query: @escaping (State) -> Set<Control>,
    effects: @escaping (Control) -> Observable<Event>
    ) -> (ObservableSchedulerContext<State>) -> Observable<Event> {
    return { state in
        let query = state.map(query)

        let newQueries = Observable.zip(query, query.startWith(Set())) { $0.subtracting($1) }

        return newQueries.flatMap { controls in
            return Observable.merge(controls.map { control -> Observable<Event> in
                return query.filter { !$0.contains(control) }
                    .map { _ in Observable<Event>.empty() }
                    .startWith(effects(control).enqueue(state.scheduler))
                    .switchLatest()
            })
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
public func react<State, Control, Event>(
    query: @escaping (State) -> Set<Control>,
    effects: @escaping (Control) -> Signal<Event>
    ) -> (Driver<State>) -> Signal<Event> {
    return { state in
        let query = state.map(query)

        let newQueries = Driver.zip(query, query.startWith(Set())) { $0.subtracting($1) }

        return newQueries.flatMap { controls in
            return Signal.merge(controls.map { control -> Signal<Event> in
                return query.filter { !$0.contains(control) }
                    .map { _ in Signal<Event>.empty() }
                    .startWith(effects(control).enqueue())
                    .switchLatest()
            })
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

extension SharedSequence where SharingStrategy == SignalSharingStrategy {
    fileprivate func enqueue() -> Signal<Element> {
        return self.asObservable()
            // observe on is here because results should be cancelable
            .observeOn(S.scheduler.async)
            // subscribe on is here because side-effects also need to be cancelable
            // (smooths out any glitches caused by start-cancel immediatelly)
            .subscribeOn(S.scheduler.async)
            .asSignal(onErrorSignalWith: Signal.empty())
    }
}

public enum UI {}

extension UI {

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
        public init(subscriptions: [Disposable], events: [Signal<Event>]) {
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
    public static func bind<State, Event>(_ bindings: @escaping (Driver<State>) -> (Bindings<Event>)) -> (Driver<State>) -> Signal<Event> {
        return { (state: Driver<State>) -> Signal<Event> in
            return Observable<Event>.using({ () -> Bindings<Event> in
                return bindings(state)
            }, observableFactory: { (bindings: Bindings<Event>) -> Observable<Event> in
                return Observable<Event>.merge(bindings.events)
            }).asSignal(onErrorSignalWith: .empty())
                .enqueue()
        }
    }

    /**
     Bi-directional binding of a system State to UI and UI into Events,
     Strongify owner.
     */
    public static func bind<State, Event, WeakOwner>(_ owner: WeakOwner, _ bindings: @escaping (WeakOwner, Driver<State>) -> (Bindings<Event>))
        -> (Driver<State>) -> Signal<Event> where WeakOwner: AnyObject {
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
