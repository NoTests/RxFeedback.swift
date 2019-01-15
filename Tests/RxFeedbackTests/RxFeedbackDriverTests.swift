//
//  RxFeedbackDriverTests.swift
//  RxFeedbackTests
//
//  Created by Krunoslav Zaher on 8/13/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import Foundation
import RxCocoa
import RxFeedback
import RxSwift
import RxTest
import XCTest

class RxFeedbackDriverTests: RxTest {}

extension RxFeedbackDriverTests {
    func testInitial() {
        let system = Driver.system(
            initialState: "initial",
            reduce: { _, newState in
                newState
            },
            feedback: [] as [Driver<Any>.Feedback<String, String>])

        var state = ""
        _ = system.drive(
            onNext: { nextState in
                state = nextState
        })

        XCTAssertEqual(state, "initial")
    }

    func testImmediateFeedbackLoop() {
        let system = Driver.system(
            initialState: "initial",
            reduce: { oldState, append in
                oldState + append
            },
            feedback: { state in
                state.flatMapLatest { state -> Signal<String> in
                    if state == "initial" {
                        return Signal.just("_a").delay(0.01)
                    }
                    else if state == "initial_a" {
                        return Signal.just("_b")
                    }
                    else if state == "initial_a_b" {
                        return Signal.just("_c")
                    }
                    else {
                        return Signal.never()
                    }
                }
        })

        let result = (
            try?
                system
                .asObservable()
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
        let feedbackLoop: (Driver<String>) -> Signal<String> = { state in
            state.flatMapLatest { state -> Signal<String> in
                if state == "initial" {
                    return Signal.just("_a")
                }
                else if state == "initial_a" {
                    return Signal.just("_b")
                }
                else if state == "initial_a_b" {
                    return Signal.just("_c")
                }
                else {
                    return Signal.never()
                }
            }
        }

        let system = Driver.system(
            initialState: "initial",
            reduce: { oldState, append in
                oldState + append
            },
            feedback: feedbackLoop, feedbackLoop, feedbackLoop)

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
extension RxFeedbackDriverTests {
    func testImmediateFeedbackLoopParallel_react_non_equatable() {
        let feedbackLoop: (Driver<String>) -> Signal<String> = react(request: { $0.needsToAppendDot }) { (_: Bool) -> Signal<String> in
            return Signal.just("_.")
        }

        let system = Driver.system(
            initialState: "initial",
            reduce: { oldState, append in
                oldState + append
            },
            feedback: feedbackLoop, feedbackLoop, feedbackLoop)

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
        let feedbackLoop: (Driver<String>) -> Signal<String> = react(request: { $0.needsToAppend }) { value in
            return Signal.just(value)
        }

        let system = Driver.system(
            initialState: "initial",
            reduce: { oldState, append in
                oldState + append
            },
            feedback: feedbackLoop, feedbackLoop, feedbackLoop)

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
        let feedbackLoop: (Driver<String>) -> Signal<String> = react(requests: { $0.needsToAppendParallel }) { value in
            return Signal.just(value)
        }

        let system = Driver.system(
            initialState: "initial",
            reduce: { oldState, append in
                oldState + append
            },
            feedback: feedbackLoop, feedbackLoop, feedbackLoop)

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

extension RxFeedbackDriverTests {
    func testUIBindFeedbackLoopReentrancy() {
        let system = Driver.system(
            initialState: "initial",
            reduce: { oldState, append in
                oldState + append
            },
            feedback: RxFeedback.bind { stateAndScheduler in
                let results = stateAndScheduler.flatMap { state -> Signal<String> in
                    if state == "initial" {
                        return Signal.just("_a").delay(0.01)
                    }
                    else if state == "initial_a" {
                        return Signal.just("_b")
                    }
                    else if state == "initial_a_b" {
                        return Signal.just("_c")
                    }
                    else {
                        return Signal.never()
                    }
                }

                return Bindings(subscriptions: [], mutations: [results])
        })

        let result = (
            try?
                system
                .asObservable()
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

        let system = Driver.system(
            initialState: "initial",
            reduce: { oldState, append in
                oldState + append
            },
            feedback: RxFeedback.bind(owner) { _, stateAndScheduler in
                let results = stateAndScheduler.flatMap { state -> Signal<String> in
                    if state == "initial" {
                        return Signal.just("_a").delay(0.01)
                    }
                    else if state == "initial_a" {
                        return Signal.just("_b")
                    }
                    else if state == "initial_a_b" {
                        return Signal.just("_c")
                    }
                    else {
                        return Signal.never()
                    }
                }
                return Bindings(subscriptions: [], mutations: [results])
        })

        let result = (
            try?
                system
                .asObservable()
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

    func testBindingsAreNotDisposedWhenNoMutationsAreSpecifiedOnDriverSystem() {
        typealias State = Int
        typealias Mutation = Int
        typealias Feedback = (Driver<State>) -> Signal<Mutation>

        let testScheduler = TestScheduler(initialClock: 0)
        var testableObserver: TestableObserver<Int>!
        var subscriptionState: [Int] = []
        let timer = testScheduler.createColdObservable(
            [
                next(50, 0),
                completed(50),
        ])
            .asSignal(onErrorJustReturn: 0)

        SharingScheduler.mock(scheduler: testScheduler) {
            let player: Feedback = react(
                request: { $0 }, effects: { _ in
                    timer.map { _ in 1 }
            })

            let mockUIBindings: Feedback = RxFeedback.bind { (state: Driver<State>) in
                let subscriptions: [Disposable] = [
                    state.drive(onNext: { subscriptionState.append($0) }),
                ]
                return Bindings(subscriptions: subscriptions, mutations: [Observable<Mutation>]())
            }
            let system = Driver.system(
                initialState: 0,
                reduce: { oldState, mutation in
                    oldState + mutation
                },
                feedback: mockUIBindings, player)

            testableObserver = testScheduler.createObserver(Int.self)
            _ = system.drive(testableObserver)
            testScheduler.scheduleAt(
                200, action: {
                    testScheduler.stop()
            })
            testScheduler.start()
        }

        let correct = [
            next(2, 0),
            next(56, 1),
            next(109, 2),
            next(162, 3),
        ]
        XCTAssertEqual(testableObserver.events, correct)
        XCTAssertEqual(subscriptionState, [0, 1, 2, 3])
    }
}

extension RxFeedbackDriverTests {
    func testReactChildList_Subscription() {
        let testScheduler = TestScheduler(initialClock: 0)
        SharingScheduler.mock(scheduler: testScheduler) {
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
                    .asDriver(onErrorJustReturn: [])
                    .do(onDispose: { happened(.disposedSource) })
                return react(
                    requests: { (state: [TestChild]) in state.indexBy { $0.identifier } },
                    effects: { (initial: TestChild, state: Driver<TestChild>) -> Signal<String> in
                        happened(.effects(calledWithInitial: initial))
                        return state
                            .map { "Got \($0.value)" }
                            .do(
                                onSubscribed: { happened(.subscribed(id: initial.identifier)) },
                                onDispose: { happened(.disposed(id: initial.identifier)) }
                            )
                            .asSignal(onErrorJustReturn: "")
                    }
                )(source).asObservable()
            }

            XCTAssertEqual(verify, [
                Recorded(time: 211, value: SignificantEvent.effects(calledWithInitial: TestChild(identifier: 0, value: "1"))),
                Recorded(time: 211, value: SignificantEvent.subscribed(id: 0)),
                Recorded(time: 231, value: SignificantEvent.effects(calledWithInitial: TestChild(identifier: 1, value: "3"))),
                Recorded(time: 231, value: SignificantEvent.subscribed(id: 1)),
                Recorded(time: 241, value: SignificantEvent.disposed(id: 0)),
                Recorded(time: 1000, value: SignificantEvent.disposed(id: 1)),
                Recorded(time: 1000, value: SignificantEvent.disposedSource),
            ])

            XCTAssertEqual(results.events, [
                next(215, "Got 1"),
                next(225, "Got 2"),
                next(235, "Got 3"),
            ])
        }
    }


    func testReactChildList_Completed() {
        let testScheduler = TestScheduler(initialClock: 0)
        SharingScheduler.mock(scheduler: testScheduler) {
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
                    .asDriver(onErrorJustReturn: [])
                    .do(onDispose: { happened(.disposedSource) })
                return react(
                    requests: { (state: [TestChild]) in state.indexBy { $0.identifier } },
                    effects: { (initial: TestChild, state: Driver<TestChild>) -> Signal<String> in
                        happened(.effects(calledWithInitial: initial))
                        return state.map { "Got \($0.value)" }
                            .do(
                                onSubscribed: { happened(.subscribed(id: initial.identifier)) },
                                onDispose: { happened(.disposed(id: initial.identifier)) }
                            )
                            .asSignal(onErrorJustReturn: "")
                        }
                    )(source).asObservable()
            }

            XCTAssertEqual(verify, [
                Recorded(time: 211, value: SignificantEvent.effects(calledWithInitial: TestChild(identifier: 0, value: "1"))),
                Recorded(time: 211, value: SignificantEvent.subscribed(id: 0)),
                Recorded(time: 221, value: SignificantEvent.disposed(id: 0)),
                Recorded(time: 221, value: SignificantEvent.disposedSource),
            ])

            XCTAssertEqual(results.events, [
                next(215, "Got 1"),
                completed(222),
            ])
        }
    }

    func testReactChildList_ChildCompleted() {
        let testScheduler = TestScheduler(initialClock: 0)
        SharingScheduler.mock(scheduler: testScheduler) {
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
                    .asDriver(onErrorJustReturn: [])
                    .do(onDispose: { happened(.disposedSource) })
                return react(
                    requests: { (state: [TestChild]) in state.indexBy { $0.identifier } },
                    effects: { (initial: TestChild, state: Driver<TestChild>) -> Signal<String> in
                        happened(.effects(calledWithInitial: initial))
                        return state.asObservable()
                            .map { childState -> Event<String> in
                                guard childState.value != "3" else { return .completed }
                                return Event.next("Got \(childState.value)")
                            }
                            .dematerialize()
                            .do(
                                onSubscribed: { happened(.subscribed(id: initial.identifier)) },
                                onDispose: { happened(.disposed(id: initial.identifier)) }
                            )
                            .asSignal(onErrorJustReturn: "")
                        }
                )(source).asObservable()
            }

            XCTAssertTrue(verify == [
                Recorded(time: 211, value: SignificantEvent.effects(calledWithInitial: TestChild(identifier: 0, value: "1"))),
                Recorded(time: 211, value: SignificantEvent.subscribed(id: 0)),
                Recorded(time: 211, value: SignificantEvent.effects(calledWithInitial: TestChild(identifier: 1, value: "2"))),
                Recorded(time: 211, value: SignificantEvent.subscribed(id: 1)),
                Recorded(time: 222, value: SignificantEvent.disposed(id: 0)),
                Recorded(time: 1000, value: SignificantEvent.disposed(id: 1)),
                Recorded(time: 1000, value: SignificantEvent.disposedSource),
            ] || verify == [
                    Recorded(time: 211, value: SignificantEvent.effects(calledWithInitial: TestChild(identifier: 1, value: "2"))),
                    Recorded(time: 211, value: SignificantEvent.subscribed(id: 1)),
                    Recorded(time: 211, value: SignificantEvent.effects(calledWithInitial: TestChild(identifier: 0, value: "1"))),
                    Recorded(time: 211, value: SignificantEvent.subscribed(id: 0)),
                    Recorded(time: 222, value: SignificantEvent.disposed(id: 0)),
                    Recorded(time: 1000, value: SignificantEvent.disposed(id: 1)),
                    Recorded(time: 1000, value: SignificantEvent.disposedSource),
            ])

            XCTAssertTrue(results.events == [
                next(215, "Got 1"),
                next(216, "Got 2"),
            ] || results.events == [
                next(215, "Got 2"),
                next(216, "Got 1"),
            ])
        }
    }

    func testReactChildList_Dispose() {
        let testScheduler = TestScheduler(initialClock: 0)
        SharingScheduler.mock(scheduler: testScheduler) {
            var verify = [Recorded<SignificantEvent>]()
            func happened(_ event: SignificantEvent) {
                verify.append(Recorded(time: testScheduler.clock, value: event))
            }

            let results = testScheduler.start { () -> Observable<String> in
                let source = testScheduler.createHotObservable([
                        next(210, [TestChild(identifier: 0, value: "1"), TestChild(identifier: 1, value: "2")]),
                        next(230, [TestChild(identifier: 0, value: "4"), TestChild(identifier: 1, value: "2")]),
                    ])
                    .asDriver(onErrorJustReturn: [])
                    .do(onDispose: { happened(.disposedSource) })
                let result = react(
                    requests: { (state: [TestChild]) in state.indexBy { $0.identifier } },
                    effects: { (initial: TestChild, state: Driver<TestChild>) -> Signal<String> in
                        happened(.effects(calledWithInitial: initial))
                        return state
                            .map { "Got \($0.value)" }
                            .do(
                                onSubscribed: { happened(.subscribed(id: initial.identifier)) },
                                // Ignore identifier because the ordering is non deterministic.
                                onDispose: { happened(.disposed(id: -1)) }
                            )
                            .asSignal(onErrorJustReturn: "")
                    }
                )(source)

                // Dispose on 220
                return Observable.create { observer in
                    let subscription = result.emit(onNext: { element in
                        observer.onNext(element)
                    })
                    testScheduler.scheduleAt(220) {
                        subscription.dispose()
                    }
                    return subscription
                }
            }

            XCTAssertTrue(verify == [
                Recorded(time: 211, value: SignificantEvent.effects(calledWithInitial: TestChild(identifier: 0, value: "1"))),
                Recorded(time: 211, value: SignificantEvent.subscribed(id: 0)),
                Recorded(time: 211, value: SignificantEvent.effects(calledWithInitial: TestChild(identifier: 1, value: "2"))),
                Recorded(time: 211, value: SignificantEvent.subscribed(id: 1)),
                Recorded(time: 220, value: SignificantEvent.disposed(id: -1)),
                Recorded(time: 220, value: SignificantEvent.disposed(id: -1)),
                Recorded(time: 220, value: SignificantEvent.disposedSource),
            ] || verify == [
                Recorded(time: 211, value: SignificantEvent.effects(calledWithInitial: TestChild(identifier: 1, value: "2"))),
                Recorded(time: 211, value: SignificantEvent.subscribed(id: 1)),
                Recorded(time: 211, value: SignificantEvent.effects(calledWithInitial: TestChild(identifier: 0, value: "1"))),
                Recorded(time: 211, value: SignificantEvent.subscribed(id: 0)),
                Recorded(time: 220, value: SignificantEvent.disposed(id: -1)),
                Recorded(time: 220, value: SignificantEvent.disposed(id: -1)),
                Recorded(time: 220, value: SignificantEvent.disposedSource),
            ])

            XCTAssertTrue(results.events == [
                next(215, "Got 1"),
                next(216, "Got 2"),
            ] || results.events == [
                next(215, "Got 2"),
                next(216, "Got 1"),
            ])
        }
    }
}
