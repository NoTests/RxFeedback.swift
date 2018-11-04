//
//  Feedbacks.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 5/1/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import RxAtomic
import RxCocoa
import RxSwift

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
        state.map(query)
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
            .asSignal(onErrorSignalWith: .empty()) }
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
        state.map(query)
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
            Observable<Mutation>.merge(
                controls.map { control -> Observable<Mutation> in
                    effects(control)
                        .enqueue(state.scheduler)
                        .takeUntilWithCompletedAsync(query.filter { !$0.contains(control) }, scheduler: asyncScheduler)
                }
            )
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
            .startWith(asObservable())
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

/// This is defined outside of `react` because Swift compiler generates an `error` :(.
fileprivate class ChildLifetimeTracking<Child: Identifiable, Mutation> where Child: Equatable {
    class LifetimeToken {}

    let state = AsyncSynchronized(
        (
            isDisposed: false,
            lifetimeByIdentifier: [Child.Identity: ChildLifetime]()
        )
    )

    typealias ChildLifetime = (
        identifier: Child.Identity,
        subscription: Disposable,
        lifetimeIdentifier: LifetimeToken,
        stateBehavior: BehaviorSubject<Child>
    )

    let effects: (_ initial: Child, _ state: Observable<Child>) -> Observable<Mutation>
    let scheduler: ImmediateSchedulerType
    let observer: AnyObserver<Mutation>

    init(
        effects: @escaping (_ initial: Child, _ state: Observable<Child>) -> Observable<Mutation>,
        scheduler: ImmediateSchedulerType,
        observer: AnyObserver<Mutation>
    ) {
        self.effects = effects
        self.scheduler = scheduler
        self.observer = observer
    }

    func forwardChildState(_ childStates: [Child]) {
        self.state.async { state in
            guard !state.isDisposed else { return }
            var lifetimeToUnsubscribeByIdentifier = state.lifetimeByIdentifier
            for childState in childStates {
                if let childLifetime = state.lifetimeByIdentifier[childState.identifier] {
                    lifetimeToUnsubscribeByIdentifier.removeValue(forKey: childState.identifier)
                    guard (try? childLifetime.stateBehavior.value()) != childState else {
                        continue
                    }
                    childLifetime.stateBehavior.onNext(childState)
                } else {
                    let subscription = SingleAssignmentDisposable()
                    let childStateSubject = BehaviorSubject(value: childState)
                    let lifetime = LifetimeToken()
                    state.lifetimeByIdentifier[childState.identifier] = (
                        identifier: childState.identifier,
                        subscription: subscription,
                        lifetimeIdentifier: lifetime,
                        stateBehavior: childStateSubject
                    )
                    let childSubscription = self.effects(childState, childStateSubject.asObservable())
                        .observeOn(self.scheduler)
                        .subscribe { event in
                            self.state.async { state in
                                guard state.lifetimeByIdentifier[childState.identifier]?.lifetimeIdentifier === lifetime else { return }
                                guard !state.isDisposed else { return }
                                switch event {
                                case .next(let mutation):
                                    self.observer.onNext(mutation)
                                case .error(let error):
                                    self.observer.onError(error)
                                case .completed:
                                    break
                                }
                            }
                        }

                    subscription.setDisposable(childSubscription)
                }
            }

            lifetimeToUnsubscribeByIdentifier.values.forEach { $0.subscription.dispose() }
        }
    }

    func dispose() {
        self.state.async { state in
            defer {
                state.lifetimeByIdentifier = [:]
                state.isDisposed = true
            }

            state.lifetimeByIdentifier.values.forEach { $0.subscription.dispose() }
        }
    }
}

enum DisposeState: Int32 {
    case subscribed = 0
    case disposed = 1
}

/**
 * State: State type of the system.
 * Child: Subset of state used to control the feedback loop.

 For every uniquely identifiable child value `effects` closure is invoked with the initial value of child state and future values corresponding to the same identifier.

 Subsequent equal values of child state are not emitted.

 - parameter query: Selects child states.
 - parameter effects: Effects to perform for each unique identifier.
 - parameter initial: Initial child state.
 - parameter state: Changes of child state.
 - returns: Feedback loop performing the effects.
 */
public func react<State, Child, Mutation>(
    query: @escaping (State) -> [Child],
    effects: @escaping (_ initial: Child, _ state: Observable<Child>) -> Observable<Mutation>
) -> (ObservableSchedulerContext<State>) -> Observable<Mutation> where Child: Identifiable, Child: Equatable {
    return { stateContext in
        Observable.create { observer in
            // This additional check is needed because `state.dispose()` is async.
            var isDisposed = AtomicInt()
            isDisposed.initialize(DisposeState.subscribed.rawValue)

            let state = ChildLifetimeTracking<Child, Mutation>(
                effects: effects,
                scheduler: stateContext.scheduler,
                observer: AnyObserver { event in
                    guard isDisposed.load() == DisposeState.subscribed.rawValue else { return }
                    observer.on(event)
                }
            )

            let subscription = stateContext.source
                .map(query)
                .subscribe { event in
                    switch event {
                    case .next(let childStates):
                        state.forwardChildState(childStates)
                    case .error(let error):
                        observer.on(.error(error))
                    case .completed:
                        observer.on(.completed)
                    }
                }

            return Disposables.create {
                isDisposed.fetchOr(DisposeState.disposed.rawValue)
                state.dispose()
                subscription.dispose()
            }
        }
    }
}

/**
 * State: State type of the system.
 * Child: Subset of state used to control the feedback loop.

 For every uniquely identifiable child value `effects` closure is invoked with the initial value of child state and future values corresponding to the same identifier.

 Subsequent equal values of child state are not emitted.

 - parameter query: Selects child states.
 - parameter effects: Effects to perform for each unique identifier.
 - parameter initial: Initial child state.
 - parameter state: Changes of child state.
 - returns: Feedback loop performing the effects.
 */
public func react<State, Child, Mutation>(
    query: @escaping (State) -> [Child],
    effects: @escaping (_ initial: Child, _ state: Driver<Child>) -> Signal<Mutation>
) -> (Driver<State>) -> Signal<Mutation> where Child: Identifiable, Child: Equatable {
    return { state in
        let observableSchedulerContext = ObservableSchedulerContext<State>(
            source: state.asObservable(),
            scheduler: Signal<Mutation>.SharingStrategy.scheduler.async
        )
        return react(
            query: query,
            effects: { initial, state in
                effects(
                    initial,
                    state.asDriver(onErrorDriveWith: .empty())
                ).asObservable()
            }
        )(observableSchedulerContext)
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
        for subscription in self.subscriptions {
            subscription.dispose()
        }
    }
}

/**
 Bi-directional binding of a system State to external state machine and mutations from it.
 */
public func bind<State, Mutation>(_ bindings: @escaping (ObservableSchedulerContext<State>) -> (Bindings<Mutation>)) -> (ObservableSchedulerContext<State>) -> Observable<Mutation> {
    return { (state: ObservableSchedulerContext<State>) -> Observable<Mutation> in
        Observable<Mutation>.using(
            { () -> Bindings<Mutation> in
                bindings(state)
            }, observableFactory: { (bindings: Bindings<Mutation>) -> Observable<Mutation> in
                Observable<Mutation>
                    .merge(bindings.mutations)
                    .concat(Observable.never())
                    .enqueue(state.scheduler)
            }
        )
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
        Observable<Mutation>.using(
            { () -> Bindings<Mutation> in
                bindings(state)
            }, observableFactory: { (bindings: Bindings<Mutation>) -> Observable<Mutation> in
                Observable<Mutation>.merge(bindings.mutations).concat(Observable.never())
            }
        )
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
