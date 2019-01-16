//
//  ObservableType+Extensions.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 4/30/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import RxCocoa
import RxSwift

extension ObservableType where E == Any {
    /// Feedback loop
    public typealias Feedback<State, Mutation> = (ObservableSchedulerContext<State>) -> Observable<Mutation>
    public typealias FeedbackLoop = Feedback

    /**
     The system simulation will be started upon subscription and stopped after subscription is disposed.

     System state is represented as a `State` parameter.
     Mutations are represented by `Mutation` parameter.

     - parameter initialState: The initial state of the system.
     - parameter reduce: Calculates the new system state from the existing state and a transition mutation (system integrator, reducer).
     - parameter feedback: The feedback loops that produce mutations depending on the current system state.
     - returns: The current state of the system.
     */
    public static func system<State, Mutation>(
        initialState: State,
        reduce: @escaping (State, Mutation) -> State,
        scheduler: ImmediateSchedulerType,
        feedback: [Feedback<State, Mutation>]
    ) -> Observable<State> {
        return Observable<State>.deferred {
            let replaySubject = ReplaySubject<State>.create(bufferSize: 1)

            let asyncScheduler = scheduler.async

            let mutations: Observable<Mutation> = Observable.merge(
                feedback.map { feedback in
                    let state = ObservableSchedulerContext(source: replaySubject.asObservable(), scheduler: asyncScheduler)
                    return feedback(state)
                }
            )
            // This is protection from accidental ignoring of scheduler so
            // reentracy errors can be avoided
            .observeOn(CurrentThreadScheduler.instance)

            return mutations.scan(initialState, accumulator: reduce)
                .do(
                    onNext: { output in
                        replaySubject.onNext(output)
                    }, onSubscribed: {
                        replaySubject.onNext(initialState)
                    }
                )
                .subscribeOn(scheduler)
                .startWith(initialState)
                .observeOn(scheduler)
        }
    }

    /**
     The system simulation will be started upon subscription and stopped after subscription is disposed.

     System state is represented as a `State` parameter.
     Mutations are represented by `Mutation` parameter.

     - parameter initialState: The initial state of the system.
     - parameter reduce: Calculates the new system state from the existing state and a transition mutation (system integrator, reducer).
     - parameter feedback: The feedback loops that produce mutations depending on the current system state.
     - returns: The current state of the system.
     */
    public static func system<State, Mutation>(
        initialState: State,
        reduce: @escaping (State, Mutation) -> State,
        scheduler: ImmediateSchedulerType,
        feedback: Feedback<State, Mutation>...
    ) -> Observable<State> {
        return system(initialState: initialState, reduce: reduce, scheduler: scheduler, feedback: feedback)
    }
}

extension SharedSequenceConvertibleType where E == Any, SharingStrategy == DriverSharingStrategy {
    /// Feedback loop
    public typealias Feedback<State, Mutation> = (Driver<State>) -> Signal<Mutation>

    /**
     The system simulation will be started upon subscription and stopped after subscription is disposed.

     System state is represented as a `State` parameter.
     Mutations are represented by `Mutation` parameter.

     - parameter initialState: The initial state of the system.
     - parameter reduce: Calculates the new system state from the existing state and a transition mutation (system integrator, reducer).
     - parameter feedback: The feedback loops that produce mutations depending on the current system state.
     - returns: The current state of the system.
     */
    public static func system<State, Mutation>(
        initialState: State,
        reduce: @escaping (State, Mutation) -> State,
        feedback: [Feedback<State, Mutation>]
    ) -> Driver<State> {
        let observableFeedbacks: [(ObservableSchedulerContext<State>) -> Observable<Mutation>] = feedback.map { feedback in
            return { sharedSequence in
                feedback(sharedSequence.source.asDriver(onErrorDriveWith: Driver<State>.empty()))
                    .asObservable()
            }
        }

        return Observable<Any>.system(
            initialState: initialState,
            reduce: reduce,
            scheduler: SharingStrategy.scheduler,
            feedback: observableFeedbacks
        )
        .asDriver(onErrorDriveWith: .empty())
    }

    /**
     The system simulation will be started upon subscription and stopped after subscription is disposed.

     System state is represented as a `State` parameter.
     Mutations are represented by `Mutation` parameter.

     - parameter initialState: The initial state of the system.
     - parameter reduce: Calculates the new system state from the existing state and a transition mutation (system integrator, reducer).
     - parameter feedback: The feedback loops that produce mutations depending on the current system state.
     - returns: The current state of the system.
     */
    public static func system<State, Mutation>(
        initialState: State,
        reduce: @escaping (State, Mutation) -> State,
        feedback: Feedback<State, Mutation>...
    ) -> Driver<State> {
        return system(initialState: initialState, reduce: reduce, feedback: feedback)
    }
}

extension ImmediateSchedulerType {
    var async: ImmediateSchedulerType {
        // This is a hack because of reentrancy. We need to make sure mutations are being sent async.
        // In case MainScheduler is being used MainScheduler.asyncInstance is used to make sure state is modified async.
        // If there is some unknown scheduler instance (like TestScheduler), just use it.
        return (self as? MainScheduler).map { _ in MainScheduler.asyncInstance } ?? self
    }
}

/// Tuple of observable sequence and corresponding scheduler context on which that observable
/// sequence receives elements.
public struct ObservableSchedulerContext<Element>: ObservableType {
    public typealias E = Element

    /// Source observable sequence
    public let source: Observable<Element>

    /// Scheduler on which observable sequence receives elements
    public let scheduler: ImmediateSchedulerType

    /// Initializes self with source observable sequence and scheduler
    ///
    /// - parameter source: Source observable sequence.
    /// - parameter scheduler: Scheduler on which source observable sequence receives elements.
    public init(source: Observable<Element>, scheduler: ImmediateSchedulerType) {
        self.source = source
        self.scheduler = scheduler
    }

    public func subscribe<O: ObserverType>(_ observer: O) -> Disposable where O.E == E {
        return source.subscribe(observer)
    }
}
