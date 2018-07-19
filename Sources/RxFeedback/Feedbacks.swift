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
 * State: State type of the system.
 * Query: Subset of state used to control the feedback loop.

 When `query` returns a value, that value is being passed into `effects` lambda to decide which effects should be performed.
 In case new `query` is different from the previous one, new effects are calculated by using `effects` lambda and then performed.

 When `query` returns `nil`, feedback loops doesn't perform any effect.

 - parameter query: Part of state that controls feedback loop.
 - parameter areEqual: Part of state that controls feedback loop.
 - parameter effects: Chooses which effects to perform for certain query result.
 - returns: Feedback loop performing the effects.
 */
public func react<State, Query, Mutation>(
    query: @escaping (State) -> Query?,
    areEqual: @escaping (Query, Query) -> Bool,
    effects: @escaping (Query) -> Observable<Mutation>
    ) -> (ObservableSchedulerContext<State>) -> Observable<Mutation> {
    return { state in
        return state.map(query)
            .distinctUntilChanged { lhs, rhs in
                switch (lhs, rhs) {
                case (.none, .none): return true
                case (.none, .some): return false
                case (.some, .none): return false
                case (.some(let lhs), .some(let rhs)): return areEqual(lhs, rhs)
                }
            }
            .flatMapLatest { (control: Query?) -> Observable<Mutation> in
                guard let control = control else {
                    return Observable<Mutation>.empty()
                }

                return effects(control)
                    .enqueue(state.scheduler)
            }
    }
}

/**
 * State: State type of the system.
 * Query: Subset of state used to control the feedback loop.

 When `query` returns a value, that value is being passed into `effects` lambda to decide which effects should be performed.
 In case new `query` is different from the previous one, new effects are calculated by using `effects` lambda and then performed.

 When `query` returns `nil`, feedback loops doesn't perform any effect.

 - parameter query: Part of state that controls feedback loop.
 - parameter effects: Chooses which effects to perform for certain query result.
 - returns: Feedback loop performing the effects.
 */
public func react<State, Query: Equatable, Mutation>(
        query: @escaping (State) -> Query?,
        effects: @escaping (Query) -> Observable<Mutation>
    ) -> (ObservableSchedulerContext<State>) -> Observable<Mutation> {
    return react(query: query, areEqual: { $0 == $1 }, effects: effects)
}

/**
 * State: State type of the system.
 * Query: Subset of state used to control the feedback loop.

 When `query` returns a value, that value is being passed into `effects` lambda to decide which effects should be performed.
 In case new `query` is different from the previous one, new effects are calculated by using `effects` lambda and then performed.

 When `query` returns `nil`, feedback loops doesn't perform any effect.

 - parameter query: Part of state that controls feedback loop.
 - parameter areEqual: Part of state that controls feedback loop.
 - parameter effects: Chooses which effects to perform for certain query result.
 - returns: Feedback loop performing the effects.
 */
public func react<State, Query, Mutation>(
    query: @escaping (State) -> Query?,
    areEqual: @escaping (Query, Query) -> Bool,
    effects: @escaping (Query) -> Signal<Mutation>
    ) -> (Driver<State>) -> Signal<Mutation> {
    return { state in
        let observableSchedulerContext = ObservableSchedulerContext<State>(
            source: state.asObservable(),
            scheduler: Signal<Mutation>.SharingStrategy.scheduler.async
        )
        return react(query: query, areEqual: areEqual, effects: { effects($0).asObservable() })(observableSchedulerContext)
            .asSignal(onErrorSignalWith: .empty())
    }
}

/**
 * State: State type of the system.
 * Query: Subset of state used to control the feedback loop.

 When `query` returns a value, that value is being passed into `effects` lambda to decide which effects should be performed.
 In case new `query` is different from the previous one, new effects are calculated by using `effects` lambda and then performed.

 When `query` returns `nil`, feedback loops doesn't perform any effect.

 - parameter query: Part of state that controls feedback loop.
 - parameter effects: Chooses which effects to perform for certain query result.
 - returns: Feedback loop performing the effects.
 */
public func react<State, Query: Equatable, Mutation>(
    query: @escaping (State) -> Query?,
    effects: @escaping (Query) -> Signal<Mutation>
) -> (Driver<State>) -> Signal<Mutation> {
    return { state in
        let observableSchedulerContext = ObservableSchedulerContext<State>(
            source: state.asObservable(),
            scheduler: Signal<Mutation>.SharingStrategy.scheduler.async
        )
        return react(query: query, effects: { effects($0).asObservable() })(observableSchedulerContext)
            .asSignal(onErrorSignalWith: .empty())
    }
}

/**
 * State: State type of the system.
 * Query: Subset of state used to control the feedback loop.

 When `query` returns a value, that value is being passed into `effects` lambda to decide which effects should be performed.
 In case new `query` is different from the previous one, new effects are calculated by using `effects` lambda and then performed.

 When `query` returns `nil`, feedback loops doesn't perform any effect.

 - parameter query: Part of state that controls feedback loop.
 - parameter effects: Chooses which effects to perform for certain query result.
 - returns: Feedback loop performing the effects.
 */
public func react<State, Query, Mutation>(
    query: @escaping (State) -> Query?,
    effects: @escaping (Query) -> Observable<Mutation>
) -> (ObservableSchedulerContext<State>) -> Observable<Mutation> {
    return { state in
        return state.map(query)
            .distinctUntilChanged { $0 != nil }
            .flatMapLatest { (control: Query?) -> Observable<Mutation> in
                guard let control = control else {
                    return Observable<Mutation>.empty()
                }

                return effects(control)
                    .enqueue(state.scheduler)
        }
    }
}

/**
 * State: State type of the system.
 * Query: Subset of state used to control the feedback loop.

 When `query` returns a value, that value is being passed into `effects` lambda to decide which effects should be performed.
 In case new `query` is different from the previous one, new effects are calculated by using `effects` lambda and then performed.

 When `query` returns `nil`, feedback loops doesn't perform any effect.

 - parameter query: Part of state that controls feedback loop.
 - parameter effects: Chooses which effects to perform for certain query result.
 - returns: Feedback loop performing the effects.
 */
public func react<State, Query, Mutation>(
    query: @escaping (State) -> Query?,
    effects: @escaping (Query) -> Signal<Mutation>
) -> (Driver<State>) -> Signal<Mutation> {
    return { state in
        let observableSchedulerContext = ObservableSchedulerContext<State>(
            source: state.asObservable(),
            scheduler: Signal<Mutation>.SharingStrategy.scheduler.async
        )
        return react(query: query, effects: { effects($0).asObservable() })(observableSchedulerContext)
            .asSignal(onErrorSignalWith: .empty())
    }
}

/**
 * State: State type of the system.
 * Query: Subset of state used to control the feedback loop.

 When `query` returns some set of values, each value is being passed into `effects` lambda to decide which effects should be performed.

 * Effects are not interrupted for elements in the new `query` that were present in the `old` query.
 * Effects are cancelled for elements present in `old` query but not in `new` query.
 * In case new elements are present in `new` query (and not in `old` query) they are being passed to the `effects` lambda and resulting effects are being performed.

 - parameter query: Part of state that controls feedback loop.
 - parameter effects: Chooses which effects to perform for certain query element.
 - returns: Feedback loop performing the effects.
 */
public func react<State, Query, Mutation>(
    query: @escaping (State) -> Set<Query>,
    effects: @escaping (Query) -> Observable<Mutation>
    ) -> (ObservableSchedulerContext<State>) -> Observable<Mutation> {
    return { state in
        let query = state.map(query)
            .share(replay: 1)

        let newQueries = Observable.zip(query, query.startWith(Set())) { $0.subtracting($1) }
        let asyncScheduler = state.scheduler.async

        return newQueries.flatMap { controls in
            return Observable<Mutation>.merge(controls.map { control -> Observable<Mutation> in
                return effects(control)
                    .enqueue(state.scheduler)
                    .takeUntilWithCompletedAsync(query.filter { !$0.contains(control) }, scheduler: asyncScheduler)
            })
        }
    }
}

extension ObservableType {
    // This is important to avoid reentrancy issues. Completed mutation is only used for cleanup
    fileprivate func takeUntilWithCompletedAsync<O>(_ other: Observable<O>, scheduler: ImmediateSchedulerType) -> Observable<E> {
            // this little piggy will delay completed mutation
            let completeAsSoonAsPossible = Observable<E>.empty().observeOn(scheduler)
            return other
                .take(1)
                .map { _ in completeAsSoonAsPossible }
                // this little piggy will ensure self is being run first
                .startWith(self.asObservable())
                // this little piggy will ensure that new mutations are being blocked immediatelly
                .switchLatest()
    }
}

/**
 * State: State type of the system.
 * Query: Subset of state used to control the feedback loop.

 When `query` returns some set of values, each value is being passed into `effects` lambda to decide which effects should be performed.

 * Effects are not interrupted for elements in the new `query` that were present in the `old` query.
 * Effects are cancelled for elements present in `old` query but not in `new` query.
 * In case new elements are present in `new` query (and not in `old` query) they are being passed to the `effects` lambda and resulting effects are being performed.

 - parameter query: Part of state that controls feedback loop.
 - parameter effects: Chooses which effects to perform for certain query element.
 - returns: Feedback loop performing the effects.
 */
public func react<State, Query, Mutation>(
    query: @escaping (State) -> Set<Query>,
    effects: @escaping (Query) -> Signal<Mutation>
    ) -> (Driver<State>) -> Signal<Mutation> {
    return { (state: Driver<State>) -> Signal<Mutation> in
        let observableSchedulerContext = ObservableSchedulerContext<State>(
            source: state.asObservable(),
            scheduler: Signal<Mutation>.SharingStrategy.scheduler.async
        )
        return react(query: query, effects: { effects($0).asObservable() })(observableSchedulerContext)
            .asSignal(onErrorSignalWith: .empty())
    }
}


extension Observable {
    fileprivate func enqueue(_ scheduler: ImmediateSchedulerType) -> Observable<Element> {
        return self
            // observe on is here because results should be cancelable
            .observeOn(scheduler.async)
            // subscribe on is here because side-effects also need to be cancelable
            // (smooths out any glitches caused by start-cancel immediatelly)
            .subscribeOn(scheduler.async)
    }
}

/**
 Contains subscriptions and mutations.
 - `subscriptions` map a system state to UI presentation.
 - `mutations` map mutations from UI to mutations of a given system.
*/
public class Bindings<Mutation>: Disposable {
    fileprivate let subscriptions: [Disposable]
    fileprivate let mutations: [Observable<Mutation>]

    /**
     - parameters:
        - subscriptions: mappings of a system state to UI presentation.
        - mutations: mappings of mutations from UI to mutations of a given system
     */
    public init(subscriptions: [Disposable], mutations: [Observable<Mutation>]) {
        self.subscriptions = subscriptions
        self.mutations = mutations
    }

    /**
     - parameters:
        - subscriptions: mappings of a system state to UI presentation.
        - mutations: mappings of mutations from UI to mutations of a given system
     */
    public init(subscriptions: [Disposable], mutations: [Signal<Mutation>]) {
        self.subscriptions = subscriptions
        self.mutations = mutations.map { $0.asObservable() }
    }

    public func dispose() {
        for subscription in subscriptions {
            subscription.dispose()
        }
    }
}

/**
 Bi-directional binding of a system State to external state machine and mutations from it.
 */
public func bind<State, Mutation>(_ bindings: @escaping (ObservableSchedulerContext<State>) -> (Bindings<Mutation>)) -> (ObservableSchedulerContext<State>) -> Observable<Mutation> {
    return { (state: ObservableSchedulerContext<State>) -> Observable<Mutation> in
        return Observable<Mutation>.using({ () -> Bindings<Mutation> in
            return bindings(state)
        }, observableFactory: { (bindings: Bindings<Mutation>) -> Observable<Mutation> in
            return Observable<Mutation>
                    .merge(bindings.mutations)
                    .concat(Observable.never())
                    .enqueue(state.scheduler)
        })
    }
}

/**
 Bi-directional binding of a system State to external state machine and mutations from it.
 Strongify owner.
 */
public func bind<State, Mutation, WeakOwner>(_ owner: WeakOwner, _ bindings: @escaping (WeakOwner, ObservableSchedulerContext<State>) -> (Bindings<Mutation>))
    -> (ObservableSchedulerContext<State>) -> Observable<Mutation> where WeakOwner: AnyObject {
        return bind(bindingsStrongify(owner, bindings))
}

/**
 Bi-directional binding of a system State to external state machine and mutations from it.
 */
public func bind<State, Mutation>(_ bindings: @escaping (Driver<State>) -> (Bindings<Mutation>)) -> (Driver<State>) -> Signal<Mutation> {
    return { (state: Driver<State>) -> Signal<Mutation> in
        return Observable<Mutation>.using({ () -> Bindings<Mutation> in
            return bindings(state)
        }, observableFactory: { (bindings: Bindings<Mutation>) -> Observable<Mutation> in
            return Observable<Mutation>.merge(bindings.mutations).concat(Observable.never())
        })
            .enqueue(Signal<Mutation>.SharingStrategy.scheduler)
            .asSignal(onErrorSignalWith: .empty())

    }
}

/**
 Bi-directional binding of a system State to external state machine and mutations from it.
 Strongify owner.
 */
public func bind<State, Mutation, WeakOwner>(_ owner: WeakOwner, _ bindings: @escaping (WeakOwner, Driver<State>) -> (Bindings<Mutation>))
    -> (Driver<State>) -> Signal<Mutation> where WeakOwner: AnyObject {
    return bind(bindingsStrongify(owner, bindings))
}

private func bindingsStrongify<Mutation, O, WeakOwner>(_ owner: WeakOwner, _ bindings: @escaping (WeakOwner, O) -> (Bindings<Mutation>))
    -> (O) -> (Bindings<Mutation>) where WeakOwner: AnyObject {
    return { [weak owner] state -> Bindings<Mutation> in
        guard let strongOwner = owner else {
            return Bindings(subscriptions: [], mutations: [Observable<Mutation>]())
        }
        return bindings(strongOwner, state)
    }
}
