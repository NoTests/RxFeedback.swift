//
//  RxFeedbackObservableTests.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 8/13/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import Foundation
import RxBlocking
import RxFeedback
import RxSwift
import RxTest
import XCTest

class RxFeedbackObservableTests: RxTest {}

extension RxFeedbackObservableTests {
    func testMutationsAreArrivingOnCorrectScheduler() {
        let scheduler = SerialDispatchQueueScheduler(qos: .userInitiated)
        let system = Observable.system(
            initialState: "initial",
            reduce: { oldState, append in
                oldState + "_" + append
            },
            scheduler: scheduler,
            scheduledFeedback: { _ in .just("a") })

        let results = try! system
            .take(2)
            .do(
                onNext: { _ in
                    XCTAssertTrue(DispatchQueue.isUserInitiated)
                }, onCompleted: {
                    XCTAssertTrue(DispatchQueue.isUserInitiated)
            })
            .toBlocking()
            .toArray()

        XCTAssertEqual(results, ["initial", "initial_a"])
    }

    func testInitial() {
        let system = Observable.system(
            initialState: "initial",
            reduce: { _, newState in
                newState
            },
            scheduler: MainScheduler.instance,
            scheduledFeedback: [])

        var state = ""
        _ = system.subscribe(
            onNext: { nextState in
                state = nextState
        })

        XCTAssertEqual(state, "initial")
    }

    func testImmediateFeedbackLoop() {
        let system = Observable.system(
            initialState: "initial",
            reduce: { oldState, append in
                oldState + append
            },
            scheduler: MainScheduler.instance,
            scheduledFeedback: { stateAndScheduler in
                stateAndScheduler.flatMap { state -> Observable<String> in
                    if state == "initial" {
                        return Observable.just("_a").delay(0.01, scheduler: MainScheduler.instance)
                    }
                    else if state == "initial_a" {
                        return Observable.just("_b")
                    }
                    else if state == "initial_a_b" {
                        return Observable.just("_c")
                    }
                    else {
                        return Observable.never()
                    }
                }
        })

        let result = (
            try?
                system
                .take(4)
                .timeout(0.5, other: Observable.empty(), scheduler: MainScheduler.instance)
                .toBlocking(timeout: 3.0)
                .toArray()) ?? []

        XCTAssertEqual(
            result, [
                "initial",
                "initial_a",
                "initial_a_b",
                "initial_a_b_c",
        ])
    }

    func testImmediateFeedbackLoopParallel() {
        let feedbackLoop: (ObservableSchedulerContext<String>) -> Observable<String> = { stateAndScheduler in
            stateAndScheduler.flatMap { state -> Observable<String> in
                if state == "initial" {
                    return Observable.just("_a")
                }
                else if state == "initial_a" {
                    return Observable.just("_b")
                }
                else if state == "initial_a_b" {
                    return Observable.just("_c")
                }
                else {
                    return Observable.never()
                }
            }
        }

        let system = Observable.system(
            initialState: "initial",
            reduce: { oldState, append in
                oldState + append
            },
            scheduler: MainScheduler.instance,
            scheduledFeedback: feedbackLoop, feedbackLoop, feedbackLoop)

        let result = (
            try?
                system
                .asObservable()
                .timeout(0.5, other: Observable.empty(), scheduler: MainScheduler.instance)
                .toBlocking(timeout: 3.0)
                .toArray()) ?? []

        XCTAssertEqual(
            result, [
                "initial",
                "initial_a",
                "initial_a_a",
                "initial_a_a_a",
                "initial_a_a_a_b",
                "initial_a_a_a_b_b",
                "initial_a_a_a_b_b_b",
        ])
    }
}

// Feedback loops
extension RxFeedbackObservableTests {
    func testImmediateFeedbackLoopParallel_react_non_equatable() {
        let feedbackLoop: (ObservableSchedulerContext<String>) -> Observable<String> = react(query: { $0.needsToAppendDot }) { _ in
            return Observable.just("_.")
        }

        let system = Observable.system(
            initialState: "initial",
            reduce: { oldState, append in
                oldState + append
            },
            scheduler: MainScheduler.instance,
            scheduledFeedback: feedbackLoop, feedbackLoop, feedbackLoop)

        let result = (
            try?
                system
                .asObservable()
                .timeout(0.5, other: Observable.empty(), scheduler: MainScheduler.instance)
                .toBlocking(timeout: 3.0)
                .toArray()) ?? []

        XCTAssertEqual(
            result, [
                "initial",
                "initial_.",
                "initial_._.",
                "initial_._._.",
        ])
    }

    func testImmediateFeedbackLoopParallel_react_equatable() {
        let feedbackLoop: (ObservableSchedulerContext<String>) -> Observable<String> = react(query: { $0.needsToAppend }) { value in
            return Observable.just(value)
        }

        let system = Observable.system(
            initialState: "initial",
            reduce: { oldState, append in
                oldState + append
            },
            scheduler: MainScheduler.instance,
            scheduledFeedback: feedbackLoop, feedbackLoop, feedbackLoop)

        let result = (
            try?
                system
                .asObservable()
                .timeout(0.5, other: Observable.empty(), scheduler: MainScheduler.instance)
                .toBlocking(timeout: 3.0)
                .toArray()) ?? []

        XCTAssertEqual(
            result, [
                "initial",
                "initial_a",
                "initial_a_b",
                "initial_a_b_c",
        ])
    }

    func testImmediateFeedbackLoopParallel_react_set() {
        let feedbackLoop: (ObservableSchedulerContext<String>) -> Observable<String> = react(query: { $0.needsToAppendParallel }) { value in
            return Observable.just(value)
        }

        let system = Observable.system(
            initialState: "initial",
            reduce: { oldState, append in
                oldState + append
            },
            scheduler: MainScheduler.instance,
            scheduledFeedback: feedbackLoop, feedbackLoop, feedbackLoop)

        let result = (
            try?
                system
                .asObservable()
                .timeout(0.5, other: Observable.empty(), scheduler: MainScheduler.instance)
                .toBlocking(timeout: 3.0)
                .toArray()) ?? []

        XCTAssertTrue(result[1].contains("_a") || result[1].contains("_b"))
        XCTAssertTrue(result[2].contains("_a") || result[2].contains("_b"))
        XCTAssertTrue(result[1].contains("_a") || result[2].contains("_a"))
        XCTAssertTrue(result[1].contains("_b") || result[2].contains("_b"))

        var ignoringAB = result

        for i in 0 ..< result.count {
            ignoringAB[i] = ignoringAB[i].replacingOccurrences(of: "_a", with: "_x")
            ignoringAB[i] = ignoringAB[i].replacingOccurrences(of: "_b", with: "_x")
        }

        XCTAssertEqual(
            ignoringAB, [
                "initial",
                "initial_x",
                "initial_x_x",
                "initial_x_x_c",
                "initial_x_x_c_c",
                "initial_x_x_c_c_c",
        ])
    }
}

extension RxFeedbackObservableTests {
    func testUIBindFeedbackLoopReentrancy() {
        let system = Observable.system(
            initialState: "initial",
            reduce: { oldState, append in
                oldState + append
            },
            scheduler: MainScheduler.instance,
            scheduledFeedback: RxFeedback.bind { stateAndScheduler in
                let results = stateAndScheduler.flatMap { state -> Observable<String> in
                    if state == "initial" {
                        return Observable.just("_a").delay(0.01, scheduler: MainScheduler.instance)
                    }
                    else if state == "initial_a" {
                        return Observable.just("_b")
                    }
                    else if state == "initial_a_b" {
                        return Observable.just("_c")
                    }
                    else {
                        return Observable.never()
                    }
                }

                return Bindings(subscriptions: [], mutations: [results])
        })

        let result = (
            try?
                system
                .take(4)
                .timeout(0.5, other: Observable.empty(), scheduler: MainScheduler.instance)
                .toBlocking(timeout: 3.0)
                .toArray()) ?? []

        XCTAssertEqual(
            result, [
                "initial",
                "initial_a",
                "initial_a_b",
                "initial_a_b_c",
        ])
    }

    func testUIBindFeedbackWithOwnerLoopReentrancy() {
        let owner = NSObject()

        let system = Observable.system(
            initialState: "initial",
            reduce: { oldState, append in
                oldState + append
            },
            scheduler: MainScheduler.instance,
            scheduledFeedback: RxFeedback.bind(owner) { _, stateAndScheduler in
                let results = stateAndScheduler.flatMap { state -> Observable<String> in
                    if state == "initial" {
                        return Observable.just("_a").delay(0.01, scheduler: MainScheduler.instance)
                    }
                    else if state == "initial_a" {
                        return Observable.just("_b")
                    }
                    else if state == "initial_a_b" {
                        return Observable.just("_c")
                    }
                    else {
                        return Observable.never()
                    }
                }

                return Bindings(subscriptions: [], mutations: [results])
        })

        let result = (
            try?
                system
                .take(4)
                .timeout(0.5, other: Observable.empty(), scheduler: MainScheduler.instance)
                .toBlocking(timeout: 3.0)
                .toArray()) ?? []

        XCTAssertEqual(
            result, [
                "initial",
                "initial_a",
                "initial_a_b",
                "initial_a_b_c",
        ])
    }

    func testBindingsAreNotDisposedWhenNoMutationsAreSpecifiedOnObservableSystem() {
        typealias State = Int
        typealias Mutation = Int
        typealias Feedback = (ObservableSchedulerContext<State>) -> Observable<Mutation>

        let testScheduler = TestScheduler(initialClock: 0)
        let timer = testScheduler.createColdObservable(
            [
                next(50, 1),
                completed(50),
        ])

        var subscriptionState: [Int] = []
        var subscriptionIsDisposed = false
        let player: Feedback = react(
            query: { $0 }, effects: { _ in
                timer.map { _ in 1 }
        })

        let mockUIBindings: Feedback = RxFeedback.bind { state in
            let subscriptions: [Disposable] = [
                state
                    .do(onDispose: { subscriptionIsDisposed = true })
                    .subscribe(onNext: { subscriptionState.append($0) }),
            ]

            return Bindings(subscriptions: subscriptions, mutations: [Observable<Mutation>]())
        }

        let system = Observable.system(
            initialState: 0,
            reduce: { oldState, mutation in
                oldState + mutation
            },
            scheduler: testScheduler,
            scheduledFeedback: mockUIBindings, player)

        let observer = testScheduler.createObserver(Int.self)
        _ = system.subscribe(observer)
        testScheduler.scheduleAt(
            200,
            action: { testScheduler.stop() }
        )
        testScheduler.start()
        let correct = [
            next(1, 0),
            next(54, 1),
            next(106, 2),
            next(158, 3),
        ]
        XCTAssertEqual(observer.events, correct)
        XCTAssertEqual(subscriptionState, [0, 1, 2, 3])
        XCTAssertFalse(subscriptionIsDisposed, "Bindings have been disposed of prematurely.")
    }
}

enum SignificantEvent: Equatable {
    case effects(calledWithInitial: TestChild)
    case subscribed(id: Int)
    case disposed(id: Int)
    case disposedSource
}

enum TestError: Error {
    case error1
}

extension RxFeedbackObservableTests {
    func testReactChildList_Subscription() {
        let testScheduler = TestScheduler(initialClock: 0)
        var verify = [Recorded<SignificantEvent>]()
        func happened(_ event: SignificantEvent) {
            verify.append(Recorded(time: testScheduler.clock, value: event))
        }

        let results = testScheduler.start { () -> Observable<String> in
            let source = testScheduler.createHotObservable([
                    next(210, [TestChild(identifier: 0, value: "1")]),
                    next(220, [TestChild(identifier: 0, value: "2")]),
                    next(230, [TestChild(identifier: 0, value: "2"), .init(identifier: 1, value: "3")]),
                    next(240, [TestChild(identifier: 1, value: "3")]),
                ])
                .asObservable()
                .do(onDispose: { happened(.disposedSource) })
            let context = ObservableSchedulerContext(
                source: source,
                scheduler: testScheduler
            )
            return react(
                childQuery: { (state: [TestChild]) in state },
                effects: { (initial: TestChild, state: Observable<TestChild>) -> Observable<String> in
                    happened(.effects(calledWithInitial: initial))
                    return state.map { "Got \($0.value)" }
                        .do(
                            onSubscribed: { happened(.subscribed(id: initial.identifier)) },
                            onDispose: { happened(.disposed(id: initial.identifier)) }
                        )
                }
            )(context)
        }

        XCTAssertEqual(verify, [
            Recorded(time: 210, value: SignificantEvent.effects(calledWithInitial: TestChild(identifier: 0, value: "1"))),
            Recorded(time: 210, value: SignificantEvent.subscribed(id: 0)),
            Recorded(time: 230, value: SignificantEvent.effects(calledWithInitial: TestChild(identifier: 1, value: "3"))),
            Recorded(time: 230, value: SignificantEvent.subscribed(id: 1)),
            Recorded(time: 240, value: SignificantEvent.disposed(id: 0)),
            Recorded(time: 1000, value: SignificantEvent.disposed(id: 1)),
            Recorded(time: 1000, value: SignificantEvent.disposedSource),
        ])

        XCTAssertEqual(results.events, [
            next(211, "Got 1"),
            next(221, "Got 2"),
            next(231, "Got 3"),
        ])
    }


    func testReactChildList_Error() {
        let testScheduler = TestScheduler(initialClock: 0)
        var verify = [Recorded<SignificantEvent>]()
        func happened(_ event: SignificantEvent) {
            verify.append(Recorded(time: testScheduler.clock, value: event))
        }

        let results = testScheduler.start { () -> Observable<String> in
            let source = testScheduler.createHotObservable([
                    next(210, [TestChild(identifier: 0, value: "1")]),
                    error(220, TestError.error1),
                    next(230, [TestChild(identifier: 0, value: "2")])
                ])
                .asObservable()
                .do(onDispose: { happened(.disposedSource) })
            let context = ObservableSchedulerContext(
                source: source,
                scheduler: testScheduler
            )
            return react(
                childQuery: { (state: [TestChild]) in state },
                effects: { (initial: TestChild, state: Observable<TestChild>) -> Observable<String> in
                    happened(.effects(calledWithInitial: initial))
                    return state.map { "Got \($0.value)" }
                        .do(
                            onSubscribed: { happened(.subscribed(id: initial.identifier)) },
                            onDispose: { happened(.disposed(id: initial.identifier)) }
                    )
                }
            )(context)
        }

        XCTAssertEqual(verify, [
            Recorded(time: 210, value: SignificantEvent.effects(calledWithInitial: TestChild(identifier: 0, value: "1"))),
            Recorded(time: 210, value: SignificantEvent.subscribed(id: 0)),
            Recorded(time: 220, value: SignificantEvent.disposed(id: 0)),
            Recorded(time: 220, value: SignificantEvent.disposedSource),
        ])

        XCTAssertEqual(results.events, [
            next(211, "Got 1"),
            error(220, TestError.error1)
        ])
    }

    func testReactChildList_Completed() {
        let testScheduler = TestScheduler(initialClock: 0)
        var verify = [Recorded<SignificantEvent>]()
        func happened(_ event: SignificantEvent) {
            verify.append(Recorded(time: testScheduler.clock, value: event))
        }

        let results = testScheduler.start { () -> Observable<String> in
            let source = testScheduler.createHotObservable([
                    next(210, [TestChild(identifier: 0, value: "1")]),
                    completed(220),
                    next(230, [TestChild(identifier: 0, value: "2")])
                ])
                .asObservable()
                .do(onDispose: { happened(.disposedSource) })
            let context = ObservableSchedulerContext(
                source: source,
                scheduler: testScheduler
            )
            return react(
                childQuery: { (state: [TestChild]) in state },
                effects: { (initial: TestChild, state: Observable<TestChild>) -> Observable<String> in
                    happened(.effects(calledWithInitial: initial))
                    return state
                        .map { "Got \($0.value)" }
                        .do(
                            onSubscribed: { happened(.subscribed(id: initial.identifier)) },
                            onDispose: { happened(.disposed(id: initial.identifier)) }
                        )
                }
            )(context)
        }

        XCTAssertEqual(verify, [
            Recorded(time: 210, value: SignificantEvent.effects(calledWithInitial: TestChild(identifier: 0, value: "1"))),
            Recorded(time: 210, value: SignificantEvent.subscribed(id: 0)),
            Recorded(time: 220, value: SignificantEvent.disposed(id: 0)),
            Recorded(time: 220, value: SignificantEvent.disposedSource),
        ])

        XCTAssertEqual(results.events, [
            next(211, "Got 1"),
            completed(220),
        ])
    }

    func testReactChildList_ChildError() {
        let testScheduler = TestScheduler(initialClock: 0)
        var verify = [Recorded<SignificantEvent>]()
        func happened(_ event: SignificantEvent) {
            verify.append(Recorded(time: testScheduler.clock, value: event))
        }

        let results = testScheduler.start { () -> Observable<String> in
            let source = testScheduler.createHotObservable([
                    next(210, [TestChild(identifier: 0, value: "1"), TestChild(identifier: 1, value: "2")]),
                    next(220, [TestChild(identifier: 0, value: "3"), TestChild(identifier: 1, value: "2")]),
                ])
                .asObservable()
                .do(onDispose: { happened(.disposedSource) })
            let context = ObservableSchedulerContext(
                source: source,
                scheduler: testScheduler
            )
            return react(
                childQuery: { (state: [TestChild]) in state },
                effects: { (initial: TestChild, state: Observable<TestChild>) -> Observable<String> in
                    happened(.effects(calledWithInitial: initial))
                    return state.map {
                            guard $0.value != "3" else { throw TestError.error1 }
                            return "Got \($0.value)"
                        }
                        .do(
                            onSubscribed: { happened(.subscribed(id: initial.identifier)) },
                            onDispose: { happened(.disposed(id: initial.identifier)) }
                        )
                }
            )(context)
        }

        XCTAssertEqual(verify, [
            Recorded(time: 210, value: SignificantEvent.effects(calledWithInitial: TestChild(identifier: 0, value: "1"))),
            Recorded(time: 210, value: SignificantEvent.subscribed(id: 0)),
            Recorded(time: 210, value: SignificantEvent.effects(calledWithInitial: TestChild(identifier: 1, value: "2"))),
            Recorded(time: 210, value: SignificantEvent.subscribed(id: 1)),
            Recorded(time: 220, value: SignificantEvent.disposed(id: 0)),
            Recorded(time: 221, value: SignificantEvent.disposedSource),
            Recorded(time: 221, value: SignificantEvent.disposed(id: 1))
        ])

        XCTAssertEqual(results.events, [
            next(211, "Got 1"),
            next(211, "Got 2"),
            error(221, TestError.error1)
        ])
    }

    func testReactChildList_ChildCompleted() {
        let testScheduler = TestScheduler(initialClock: 0)
        var verify = [Recorded<SignificantEvent>]()
        func happened(_ event: SignificantEvent) {
            verify.append(Recorded(time: testScheduler.clock, value: event))
        }

        let results = testScheduler.start { () -> Observable<String> in
            let source = testScheduler.createHotObservable([
                    next(210, [TestChild(identifier: 0, value: "1"), TestChild(identifier: 1, value: "2")]),
                    next(220, [TestChild(identifier: 0, value: "3"), TestChild(identifier: 1, value: "2")]),
                    next(230, [TestChild(identifier: 0, value: "4"), TestChild(identifier: 1, value: "2")]),
                ])
                .asObservable()
                .do(onDispose: { happened(.disposedSource) })
            let context = ObservableSchedulerContext(
                source: source,
                scheduler: testScheduler
            )
            return react(
                childQuery: { (state: [TestChild]) in state },
                effects: { (initial: TestChild, state: Observable<TestChild>) -> Observable<String> in
                    happened(.effects(calledWithInitial: initial))
                    return state.map { childState -> Event<String> in
                            guard childState.value != "3" else { return .completed }
                            return Event.next("Got \(childState.value)")
                        }
                        .dematerialize()
                        .do(
                            onSubscribed: { happened(.subscribed(id: initial.identifier)) },
                            onDispose: { happened(.disposed(id: initial.identifier)) }
                        )
                }
            )(context)
        }

        XCTAssertEqual(verify, [
            Recorded(time: 210, value: SignificantEvent.effects(calledWithInitial: TestChild(identifier: 0, value: "1"))),
            Recorded(time: 210, value: SignificantEvent.subscribed(id: 0)),
            Recorded(time: 210, value: SignificantEvent.effects(calledWithInitial: TestChild(identifier: 1, value: "2"))),
            Recorded(time: 210, value: SignificantEvent.subscribed(id: 1)),
            Recorded(time: 220, value: SignificantEvent.disposed(id: 0)),
            Recorded(time: 1000, value: SignificantEvent.disposed(id: 1)),
            Recorded(time: 1000, value: SignificantEvent.disposedSource),
        ])

        XCTAssertEqual(results.events, [
            next(211, "Got 1"),
            next(211, "Got 2"),
        ])
    }

    func testReactChildList_Dispose() {
        let testScheduler = TestScheduler(initialClock: 0)
        var verify = [Recorded<SignificantEvent>]()
        func happened(_ event: SignificantEvent) {
            verify.append(Recorded(time: testScheduler.clock, value: event))
        }

        let results = testScheduler.start { () -> Observable<String> in
            let source = testScheduler.createHotObservable([
                    next(210, [TestChild(identifier: 0, value: "1"), TestChild(identifier: 1, value: "2")]),
                    next(230, [TestChild(identifier: 0, value: "4"), TestChild(identifier: 1, value: "2")]),
                ])
                .asObservable()
                .do(onDispose: { happened(.disposedSource) })
            let context = ObservableSchedulerContext(
                source: source,
                scheduler: testScheduler
            )
            let result = react(
                childQuery: { (state: [TestChild]) in state },
                effects: { (initial: TestChild, state: Observable<TestChild>) -> Observable<String> in
                    happened(.effects(calledWithInitial: initial))
                    return state.map { childState -> Event<String> in
                            guard childState.value != "3" else { return .completed }
                            return Event.next("Got \(childState.value)")
                        }
                        .dematerialize()
                        .do(
                            onSubscribed: { happened(.subscribed(id: initial.identifier)) },
                            // Ignore identifier because the ordering is non deterministic.
                            onDispose: { happened(.disposed(id: -1)) }
                        )
                }
            )(context)

            // Dispose on 220
            return Observable.create { observer in
                let subscription = result.subscribe(observer)
                testScheduler.scheduleAt(220) {
                    subscription.dispose()
                }
                return subscription
            }
        }

        XCTAssertEqual(verify, [
            Recorded(time: 210, value: SignificantEvent.effects(calledWithInitial: TestChild(identifier: 0, value: "1"))),
            Recorded(time: 210, value: SignificantEvent.subscribed(id: 0)),
            Recorded(time: 210, value: SignificantEvent.effects(calledWithInitial: TestChild(identifier: 1, value: "2"))),
            Recorded(time: 210, value: SignificantEvent.subscribed(id: 1)),
            Recorded(time: 220, value: SignificantEvent.disposed(id: -1)),
            Recorded(time: 220, value: SignificantEvent.disposed(id: -1)),
            Recorded(time: 220, value: SignificantEvent.disposedSource),
        ])

        XCTAssertEqual(results.events, [
            next(211, "Got 1"),
            next(211, "Got 2"),
            ])
    }
}

struct TestChild: Equatable, Identifiable {
    var identifier: Int
    var value: String
}

extension DispatchQueue {
    private static var token: DispatchSpecificKey<()> = {
        let key = DispatchSpecificKey<()>()
        DispatchQueue.global(qos: .userInitiated).setSpecific(key: key, value: ())
        return key
    }()

    static var isUserInitiated: Bool {
        return DispatchQueue.getSpecific(key: token) != nil
    }
}
