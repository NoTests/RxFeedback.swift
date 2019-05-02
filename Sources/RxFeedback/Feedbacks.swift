//
//  Feedbacks.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 5/1/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import RxCocoa
import RxSwift

/**
 State: State type of the system.
 Request: Subset of state used to control the feedback loop.

 When `request` returns a value, that value is being passed into `effects` lambda to decide which effects should be performed.
 In case new `request` is different from the previous one, new effects are calculated by using `effects` lambda and then performed.

 When `request` returns `nil`, feedback loops doesn't perform any effect.

 - parameter request: The request to perform some effects.
 - parameter effects: The request effects.
 - returns: The feedback loop performing the effects.
 */
public func react<State, Request: Equatable, Event>(
    request: @escaping (State) -> Request?,
    effects: @escaping (Request) -> Observable<Event>
) -> (ObservableSchedulerContext<State>) -> Observable<Event> {
    return react(
        requests: { request($0).map { value in [ConstHashable(value: value): value] } ?? [:] },
        effects: { initialValue, _ in
            return effects(initialValue)
        }
    )
}

/**
 State: State type of the system.
 Request: Subset of state used to control the feedback loop.

 When `request` returns a value, that value is being passed into `effects` lambda to decide which effects should be performed.
 In case new `request` is different from the previous one, new effects are calculated by using `effects` lambda and then performed.

 When `request` returns `nil`, feedback loops doesn't perform any effect.

 - parameter request: The request to perform some effects.
 - parameter effects: The request effects.
 - returns: The feedback loop performing the effects.
 */
public func react<State, Request: Equatable, Event>(
    request: @escaping (State) -> Request?,
    effects: @escaping (Request) -> Signal<Event>
) -> (Driver<State>) -> Signal<Event> {
    return { state in
        let observableSchedulerContext = ObservableSchedulerContext<State>(
            source: state.asObservable(),
            scheduler: Signal<Event>.SharingStrategy.scheduler.async
        )
        return react(request: request, effects: { effects($0).asObservable() })(observableSchedulerContext)
            .asSignal(onErrorSignalWith: .empty()) }
}

/**
 State: State type of the system.
 Request: Subset of state used to control the feedback loop.

 When `request` returns some set of values, each value is being passed into `effects` lambda to decide which effects should be performed.

 * Effects are not interrupted for elements in the new `request` that were present in the `old` request.
 * Effects are cancelled for elements present in `old` request but not in `new` request.
 * In case new elements are present in `new` request (and not in `old` request) they are being passed to the `effects` lambda and resulting effects are being performed.

 - parameter requests: requests to perform some effects.
 - parameter effects: The request effects.
 - returns: The feedback loop performing the effects.
 */
public func react<State, Request, Event>(
    requests: @escaping (State) -> Set<Request>,
    effects: @escaping (Request) -> Observable<Event>
) -> (ObservableSchedulerContext<State>) -> Observable<Event> {
    return react(
        requests: { Dictionary(requests($0).map { ($0, $0) }, uniquingKeysWith: { first, _ in first }) },
        effects: { initialValue, _ in
            return effects(initialValue)
        })
}

/**
 State: State type of the system.
 Request: Subset of state used to control the feedback loop.

 When `request` returns some set of values, each value is being passed into `effects` lambda to decide which effects should be performed.

 * Effects are not interrupted for elements in the new `request` that were present in the `old` request.
 * Effects are cancelled for elements present in `old` request but not in `new` request.
 * In case new elements are present in `new` request (and not in `old` request) they are being passed to the `effects` lambda and resulting effects are being performed.

 - parameter requests: Requests to perform some effects.
 - parameter effects: The request effects.
 - returns: The feedback loop performing the effects.
 */
public func react<State, Request, Event>(
    requests: @escaping (State) -> Set<Request>,
    effects: @escaping (Request) -> Signal<Event>
) -> (Driver<State>) -> Signal<Event> {
    return { (state: Driver<State>) -> Signal<Event> in
        let observableSchedulerContext = ObservableSchedulerContext<State>(
            source: state.asObservable(),
            scheduler: Signal<Event>.SharingStrategy.scheduler.async
        )
        return react(requests: requests, effects: { effects($0).asObservable() })(observableSchedulerContext)
            .asSignal(onErrorSignalWith: .empty())
    }
}

/// This is defined outside of `react` because Swift compiler generates an `error` :(.
fileprivate class RequestLifetimeTracking<Request: Equatable, RequestID: Hashable, Event> {
    class LifetimeToken {}

    let state = AsyncSynchronized(
        (
            isDisposed: false,
            lifetimeByIdentifier: [RequestID: RequestLifetime]()
        )
    )

    typealias RequestLifetime = (
        subscription: Disposable,
        lifetimeIdentifier: LifetimeToken,
        latestRequest: BehaviorSubject<Request>
    )

    let effects: (_ initial: Request, _ state: Observable<Request>) -> Observable<Event>
    let scheduler: ImmediateSchedulerType
    let observer: AnyObserver<Event>

    init(
        effects: @escaping (_ initial: Request, _ state: Observable<Request>) -> Observable<Event>,
        scheduler: ImmediateSchedulerType,
        observer: AnyObserver<Event>
    ) {
        self.effects = effects
        self.scheduler = scheduler
        self.observer = observer
    }

    func forwardRequests(_ requests: [RequestID: Request]) {
        self.state.async { state in
            guard !state.isDisposed else { return }
            var lifetimeToUnsubscribeByIdentifier = state.lifetimeByIdentifier
            for (requestID, request) in requests {
                if let requestLifetime = state.lifetimeByIdentifier[requestID] {
                    lifetimeToUnsubscribeByIdentifier.removeValue(forKey: requestID)
                    guard (try? requestLifetime.latestRequest.value()) != request else { continue }
                    requestLifetime.latestRequest.onNext(request)
                } else {
                    let subscription = SingleAssignmentDisposable()
                    let latestRequestSubject = BehaviorSubject(value: request)
                    let lifetime = LifetimeToken()
                    state.lifetimeByIdentifier[requestID] = (
                        subscription: subscription,
                        lifetimeIdentifier: lifetime,
                        latestRequest: latestRequestSubject
                    )
                    let requestsSubscription = self.effects(request, latestRequestSubject.asObservable())
                        .observeOn(self.scheduler)
                        .subscribe { event in
                            self.state.async { state in
                                guard state.lifetimeByIdentifier[requestID]?.lifetimeIdentifier === lifetime else { return }
                                guard !state.isDisposed else { return }
                                switch event {
                                case .next(let event):
                                    self.observer.onNext(event)
                                case .error(let error):
                                    self.observer.onError(error)
                                case .completed:
                                    break
                                }
                            }
                        }

                    subscription.setDisposable(requestsSubscription)
                }
            }

            lifetimeToUnsubscribeByIdentifier.keys.forEach {
              state.lifetimeByIdentifier.removeValue(forKey: $0)
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

/**
 State: State type of the system.
 Request: Subset of state used to control the feedback loop.

 For every uniquely identifiable request `effects` closure is invoked with the initial value of the request and future requests corresponding to the same identifier.

 Subsequent equal values of request are not emitted from the effects state parameter.

 - parameter requests: Requests to perform some effects.
 - parameter effects: The request effects.
 - parameter initial: Initial request.
 - parameter state: Latest request state.
 - returns: The feedback loop performing the effects.
 */
public func react<State, Request: Equatable, RequestID, Event>(
    requests: @escaping (State) -> [RequestID: Request],
    effects: @escaping (_ initial: Request, _ state: Observable<Request>) -> Observable<Event>
) -> (ObservableSchedulerContext<State>) -> Observable<Event> {
    return { stateContext in
        Observable.create { observer in
            let state = RequestLifetimeTracking<Request, RequestID, Event>(
                effects: effects,
                scheduler: stateContext.scheduler,
                observer: observer
            )

            let subscription = stateContext.source
                .map(requests)
                .subscribe { event in
                    switch event {
                    case .next(let requests):
                        state.forwardRequests(requests)
                    case .error(let error):
                        observer.on(.error(error))
                    case .completed:
                        observer.on(.completed)
                    }
                }

            return Disposables.create {
                state.dispose()
                subscription.dispose()
            }
        }
    }
}

/**
 State: State type of the system.
 Request: Subset of state used to control the feedback loop.

 For every uniquely identifiable request `effects` closure is invoked with the initial value of the request and future requests corresponding to the same identifier.

 Subsequent equal values of request are not emitted from the effects state parameter.

 - parameter requests: Requests to perform some effects.
 - parameter effects: The request effects.
 - parameter initial: Initial request.
 - parameter state: Latest request state.
 - returns: The feedback loop performing the effects.
 */
public func react<State, Request: Equatable, RequestID, Event>(
    requests: @escaping (State) -> [RequestID: Request],
    effects: @escaping (_ initial: Request, _ state: Driver<Request>) -> Signal<Event>
) -> (Driver<State>) -> Signal<Event> {
    return { state in
        let observableSchedulerContext = ObservableSchedulerContext<State>(
            source: state.asObservable(),
            scheduler: Signal<Event>.SharingStrategy.scheduler.async
        )
        return react(
            requests: requests,
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
        for subscription in self.subscriptions {
            subscription.dispose()
        }
    }
}

/**
 Bi-directional binding of a system State to external state machine and events from it.
 */
public func bind<State, Event>(_ bindings: @escaping (ObservableSchedulerContext<State>) -> (Bindings<Event>)) -> (ObservableSchedulerContext<State>) -> Observable<Event> {
    return { (state: ObservableSchedulerContext<State>) -> Observable<Event> in
        Observable<Event>.using(
            { () -> Bindings<Event> in
                bindings(state)
            }, observableFactory: { (bindings: Bindings<Event>) -> Observable<Event> in
                Observable<Event>
                    .merge(bindings.events)
                    .concat(Observable.never())
                    .enqueue(state.scheduler)
            }
        )
    }
}

/**
 Bi-directional binding of a system State to external state machine and events from it.
 Strongify owner.
 */
public func bind<State, Event, WeakOwner>(_ owner: WeakOwner, _ bindings: @escaping (WeakOwner, ObservableSchedulerContext<State>) -> (Bindings<Event>))
    -> (ObservableSchedulerContext<State>) -> Observable<Event> where WeakOwner: AnyObject {
    return bind(bindingsStrongify(owner, bindings))
}

/**
 Bi-directional binding of a system State to external state machine and events from it.
 */
public func bind<State, Event>(_ bindings: @escaping (Driver<State>) -> (Bindings<Event>)) -> (Driver<State>) -> Signal<Event> {
    return { (state: Driver<State>) -> Signal<Event> in
        Observable<Event>.using(
            { () -> Bindings<Event> in
                bindings(state)
            }, observableFactory: { (bindings: Bindings<Event>) -> Observable<Event> in
                Observable<Event>.merge(bindings.events).concat(Observable.never())
            }
        )
        .enqueue(Signal<Event>.SharingStrategy.scheduler)
        .asSignal(onErrorSignalWith: .empty())
    }
}

/**
 Bi-directional binding of a system State to external state machine and events from it.
 Strongify owner.
 */
public func bind<State, Event, WeakOwner>(_ owner: WeakOwner, _ bindings: @escaping (WeakOwner, Driver<State>) -> (Bindings<Event>))
    -> (Driver<State>) -> Signal<Event> where WeakOwner: AnyObject {
    return bind(bindingsStrongify(owner, bindings))
}

private func bindingsStrongify<Event, O, WeakOwner>(_ owner: WeakOwner, _ bindings: @escaping (WeakOwner, O) -> (Bindings<Event>))
    -> (O) -> (Bindings<Event>) where WeakOwner: AnyObject {
    return { [weak owner] state -> Bindings<Event> in
        guard let strongOwner = owner else {
            return Bindings(subscriptions: [], events: [Observable<Event>]())
        }
        return bindings(strongOwner, state)
    }
}

/// `Hashable` wrapper for `Equatable` value that returns const `hashValue`.
///
/// This looks like a performance issue, but it is ok when there is a single value present. Used in a `react` feedback loop.
fileprivate struct ConstHashable<Value: Equatable>: Hashable {
    var value: Value

    func hash(into hasher: inout Hasher) { }
}
