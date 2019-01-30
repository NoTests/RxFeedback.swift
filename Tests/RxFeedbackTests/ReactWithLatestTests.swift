//
//  ReactWithLatestTests.swift
//  RxFeedbackTests
//
//  Created by Krunoslav Zaher on 1/30/19.
//  Copyright © 2019 Krunoslav Zaher. All rights reserved.
//

import Foundation
import XCTest
import RxFeedback
import RxSwift
import RxTest

class ReactWithLatestLoopsTests: RxTest {}

enum SignificantEvent: Equatable {
    case effects(calledWithInitial: TestRequest)
    case subscribed(id: Int)
    case disposed(id: Int)
    case disposedSource
}

enum TestError: Error {
    case error1
}

extension ReactWithLatestLoopsTests {
    func testReactRequestsWithLatest_Subscription() {
        let testScheduler = TestScheduler(initialClock: 0)
        var recordedEvents = [Recorded<SignificantEvent>]()
        func recordEvent(_ event: SignificantEvent) {
            recordedEvents.append(Recorded(time: testScheduler.clock, value: event))
        }

        let results = testScheduler.start { () -> Observable<String> in
            let source = testScheduler.createHotObservable([
                    next(210, [TestRequest(identifier: 0, value: "1")]),
                    next(220, [TestRequest(identifier: 0, value: "2")]),
                    next(230, [TestRequest(identifier: 0, value: "2"), .init(identifier: 1, value: "3")]),
                    next(240, [TestRequest(identifier: 1, value: "3")]),
                    next(250, [TestRequest(identifier: 0, value: "2"), TestRequest(identifier: 1, value: "3")]),
                    next(260, [TestRequest(identifier: 1, value: "3")]),
                ])
                .asObservable()
                .do(onDispose: { recordEvent(.disposedSource) })
            let context = ObservableSchedulerContext(
                source: source,
                scheduler: testScheduler
            )
            return react(
                requests: { (state: [TestRequest]) in state.indexBy { $0.identifier } },
                effects: { (initial: TestRequest, state: Observable<TestRequest>) -> Observable<String> in
                    recordEvent(.effects(calledWithInitial: initial))
                    return state.map { "Got \($0.value)" }
                        .do(
                            onSubscribed: { recordEvent(.subscribed(id: initial.identifier)) },
                            onDispose: { recordEvent(.disposed(id: initial.identifier)) }
                        )
                }
            )(context)
        }

        XCTAssertEqual(recordedEvents, [
            Recorded(time: 210, value: SignificantEvent.effects(calledWithInitial: TestRequest(identifier: 0, value: "1"))),
            Recorded(time: 210, value: SignificantEvent.subscribed(id: 0)),
            Recorded(time: 230, value: SignificantEvent.effects(calledWithInitial: TestRequest(identifier: 1, value: "3"))),
            Recorded(time: 230, value: SignificantEvent.subscribed(id: 1)),
            Recorded(time: 240, value: SignificantEvent.disposed(id: 0)),
            Recorded(time: 250, value: SignificantEvent.effects(calledWithInitial: TestRequest(identifier: 0, value: "2"))),
            Recorded(time: 250, value: SignificantEvent.subscribed(id: 0)),
            Recorded(time: 260, value: SignificantEvent.disposed(id: 0)),
            Recorded(time: 1000, value: SignificantEvent.disposed(id: 1)),
            Recorded(time: 1000, value: SignificantEvent.disposedSource),
        ])

        XCTAssertEqual(results.events, [
            next(211, "Got 1"),
            next(221, "Got 2"),
            next(231, "Got 3"),
            next(251, "Got 2"),
        ])
    }


    func testReactRequestsWithLatest_Error() {
        let testScheduler = TestScheduler(initialClock: 0)
        var recordedEvents = [Recorded<SignificantEvent>]()
        func recordEvent(_ event: SignificantEvent) {
            recordedEvents.append(Recorded(time: testScheduler.clock, value: event))
        }

        let results = testScheduler.start { () -> Observable<String> in
            let source = testScheduler.createHotObservable([
                    next(210, [TestRequest(identifier: 0, value: "1")]),
                    error(220, TestError.error1),
                    next(230, [TestRequest(identifier: 0, value: "2")])
                ])
                .asObservable()
                .do(onDispose: { recordEvent(.disposedSource) })
            let context = ObservableSchedulerContext(
                source: source,
                scheduler: testScheduler
            )
            return react(
                requests: { (state: [TestRequest]) in state.indexBy { $0.identifier }},
                effects: { (initial: TestRequest, state: Observable<TestRequest>) -> Observable<String> in
                    recordEvent(.effects(calledWithInitial: initial))
                    return state.map { "Got \($0.value)" }
                        .do(
                            onSubscribed: { recordEvent(.subscribed(id: initial.identifier)) },
                            onDispose: { recordEvent(.disposed(id: initial.identifier)) }
                    )
                }
            )(context)
        }

        XCTAssertEqual(recordedEvents, [
            Recorded(time: 210, value: SignificantEvent.effects(calledWithInitial: TestRequest(identifier: 0, value: "1"))),
            Recorded(time: 210, value: SignificantEvent.subscribed(id: 0)),
            Recorded(time: 220, value: SignificantEvent.disposed(id: 0)),
            Recorded(time: 220, value: SignificantEvent.disposedSource),
        ])

        XCTAssertEqual(results.events, [
            next(211, "Got 1"),
            error(220, TestError.error1)
        ])
    }

    func testReactRequestsWithLatest_Completed() {
        let testScheduler = TestScheduler(initialClock: 0)
        var recordedEvents = [Recorded<SignificantEvent>]()
        func recordEvent(_ event: SignificantEvent) {
            recordedEvents.append(Recorded(time: testScheduler.clock, value: event))
        }

        let results = testScheduler.start { () -> Observable<String> in
            let source = testScheduler.createHotObservable([
                    next(210, [TestRequest(identifier: 0, value: "1")]),
                    completed(220),
                    next(230, [TestRequest(identifier: 0, value: "2")])
                ])
                .asObservable()
                .do(onDispose: { recordEvent(.disposedSource) })
            let context = ObservableSchedulerContext(
                source: source,
                scheduler: testScheduler
            )
            return react(
                requests: { (state: [TestRequest]) in state.indexBy { $0.identifier } },
                effects: { (initial: TestRequest, state: Observable<TestRequest>) -> Observable<String> in
                    recordEvent(.effects(calledWithInitial: initial))
                    return state
                        .map { "Got \($0.value)" }
                        .do(
                            onSubscribed: { recordEvent(.subscribed(id: initial.identifier)) },
                            onDispose: { recordEvent(.disposed(id: initial.identifier)) }
                        )
                }
            )(context)
        }

        XCTAssertEqual(recordedEvents, [
            Recorded(time: 210, value: SignificantEvent.effects(calledWithInitial: TestRequest(identifier: 0, value: "1"))),
            Recorded(time: 210, value: SignificantEvent.subscribed(id: 0)),
            Recorded(time: 220, value: SignificantEvent.disposed(id: 0)),
            Recorded(time: 220, value: SignificantEvent.disposedSource),
        ])

        XCTAssertEqual(results.events, [
            next(211, "Got 1"),
            completed(220),
        ])
    }

    func testReactRequestsWithLatest_RequestError() {
        let testScheduler = TestScheduler(initialClock: 0)
        var recordedEvents = [Recorded<SignificantEvent>]()
        func recordEvent(_ event: SignificantEvent) {
            recordedEvents.append(Recorded(time: testScheduler.clock, value: event))
        }

        let results = testScheduler.start { () -> Observable<String> in
            let source = testScheduler.createHotObservable([
                    next(210, [TestRequest(identifier: 0, value: "1"), TestRequest(identifier: 1, value: "2")]),
                    next(220, [TestRequest(identifier: 0, value: "3"), TestRequest(identifier: 1, value: "2")]),
                    // This should be ignored.
                    next(230, [TestRequest(identifier: 0, value: "4"), TestRequest(identifier: 1, value: "2")]),
                ])
                .asObservable()
                .do(onDispose: { recordEvent(.disposedSource) })
            let context = ObservableSchedulerContext(
                source: source,
                scheduler: testScheduler
            )
            return react(
                requests: { (state: [TestRequest]) in state.indexBy { $0.identifier } },
                effects: { (initial: TestRequest, state: Observable<TestRequest>) -> Observable<String> in
                    recordEvent(.effects(calledWithInitial: initial))
                    return state.map {
                            guard $0.value != "3" else { throw TestError.error1 }
                            return "Got \($0.value)"
                        }
                        .do(
                            onSubscribed: { recordEvent(.subscribed(id: initial.identifier)) },
                            onDispose: { recordEvent(.disposed(id: initial.identifier)) }
                        )
                }
            )(context)
        }

        XCTAssertTrue(recordedEvents == [
            Recorded(time: 210, value: SignificantEvent.effects(calledWithInitial: TestRequest(identifier: 0, value: "1"))),
            Recorded(time: 210, value: SignificantEvent.subscribed(id: 0)),
            Recorded(time: 210, value: SignificantEvent.effects(calledWithInitial: TestRequest(identifier: 1, value: "2"))),
            Recorded(time: 210, value: SignificantEvent.subscribed(id: 1)),
            Recorded(time: 220, value: SignificantEvent.disposed(id: 0)),
            Recorded(time: 221, value: SignificantEvent.disposedSource),
            Recorded(time: 221, value: SignificantEvent.disposed(id: 1))
        ] || recordedEvents == [
            Recorded(time: 210, value: SignificantEvent.effects(calledWithInitial: TestRequest(identifier: 1, value: "2"))),
            Recorded(time: 210, value: SignificantEvent.subscribed(id: 1)),
            Recorded(time: 210, value: SignificantEvent.effects(calledWithInitial: TestRequest(identifier: 0, value: "1"))),
            Recorded(time: 210, value: SignificantEvent.subscribed(id: 0)),
            Recorded(time: 220, value: SignificantEvent.disposed(id: 0)),
            Recorded(time: 221, value: SignificantEvent.disposedSource),
            Recorded(time: 221, value: SignificantEvent.disposed(id: 1))
        ])

        XCTAssertTrue(results.events == [
            next(211, "Got 1"),
            next(211, "Got 2"),
            error(221, TestError.error1)
        ] || results.events == [
            next(211, "Got 2"),
            next(211, "Got 1"),
            error(221, TestError.error1)
        ])
    }

    func testReactRequestsWithLatest_RequestCompleted() {
        let testScheduler = TestScheduler(initialClock: 0)
        var recordedEvents = [Recorded<SignificantEvent>]()
        func recordEvent(_ event: SignificantEvent) {
            recordedEvents.append(Recorded(time: testScheduler.clock, value: event))
        }

        let results = testScheduler.start { () -> Observable<String> in
            let source = testScheduler.createHotObservable([
                    next(210, [TestRequest(identifier: 0, value: "1"), TestRequest(identifier: 1, value: "2")]),
                    next(220, [TestRequest(identifier: 0, value: "3"), TestRequest(identifier: 1, value: "2")]),
                    next(230, [TestRequest(identifier: 0, value: "4"), TestRequest(identifier: 1, value: "2")]),
                ])
                .asObservable()
                .do(onDispose: { recordEvent(.disposedSource) })
            let context = ObservableSchedulerContext(
                source: source,
                scheduler: testScheduler
            )
            return react(
                requests: { (state: [TestRequest]) in state.indexBy { $0.identifier } },
                effects: { (initial: TestRequest, state: Observable<TestRequest>) -> Observable<String> in
                    recordEvent(.effects(calledWithInitial: initial))
                    return state.map { childState -> Event<String> in
                            guard childState.value != "3" else { return .completed }
                            return Event.next("Got \(childState.value)")
                        }
                        .dematerialize()
                        .do(
                            onSubscribed: { recordEvent(.subscribed(id: initial.identifier)) },
                            onDispose: { recordEvent(.disposed(id: initial.identifier)) }
                        )
                }
            )(context)
        }

        XCTAssertTrue(recordedEvents == [
            Recorded(time: 210, value: SignificantEvent.effects(calledWithInitial: TestRequest(identifier: 0, value: "1"))),
            Recorded(time: 210, value: SignificantEvent.subscribed(id: 0)),
            Recorded(time: 210, value: SignificantEvent.effects(calledWithInitial: TestRequest(identifier: 1, value: "2"))),
            Recorded(time: 210, value: SignificantEvent.subscribed(id: 1)),
            Recorded(time: 220, value: SignificantEvent.disposed(id: 0)),
            Recorded(time: 1000, value: SignificantEvent.disposed(id: 1)),
            Recorded(time: 1000, value: SignificantEvent.disposedSource),
        ] || recordedEvents == [
            Recorded(time: 210, value: SignificantEvent.effects(calledWithInitial: TestRequest(identifier: 1, value: "2"))),
            Recorded(time: 210, value: SignificantEvent.subscribed(id: 1)),
            Recorded(time: 210, value: SignificantEvent.effects(calledWithInitial: TestRequest(identifier: 0, value: "1"))),
            Recorded(time: 210, value: SignificantEvent.subscribed(id: 0)),
            Recorded(time: 220, value: SignificantEvent.disposed(id: 0)),
            Recorded(time: 1000, value: SignificantEvent.disposed(id: 1)),
            Recorded(time: 1000, value: SignificantEvent.disposedSource),
        ])

        XCTAssertTrue(results.events == [
            next(211, "Got 1"),
            next(211, "Got 2"),
        ] || results.events == [
            next(211, "Got 2"),
            next(211, "Got 1"),
        ])
    }

    func testReactRequestsWithLatest_Dispose() {
        let testScheduler = TestScheduler(initialClock: 0)
        var recordedEvents = [Recorded<SignificantEvent>]()
        func recordEvent(_ event: SignificantEvent) {
            recordedEvents.append(Recorded(time: testScheduler.clock, value: event))
        }

        let results = testScheduler.start { () -> Observable<String> in
            let source = testScheduler.createHotObservable([
                    next(210, [TestRequest(identifier: 0, value: "1"), TestRequest(identifier: 1, value: "2")]),
                    next(230, [TestRequest(identifier: 0, value: "4"), TestRequest(identifier: 1, value: "2")]),
                ])
                .asObservable()
                .do(onDispose: { recordEvent(.disposedSource) })
            let context = ObservableSchedulerContext(
                source: source,
                scheduler: testScheduler
            )
            let result = react(
                requests: { (state: [TestRequest]) in state.indexBy { $0.identifier } },
                effects: { (initial: TestRequest, state: Observable<TestRequest>) -> Observable<String> in
                    recordEvent(.effects(calledWithInitial: initial))
                    return state.map { childState -> Event<String> in
                            guard childState.value != "3" else { return .completed }
                            return Event.next("Got \(childState.value)")
                        }
                        .dematerialize()
                        .do(
                            onSubscribed: { recordEvent(.subscribed(id: initial.identifier)) },
                            // Ignore identifier because the ordering is non deterministic.
                            onDispose: { recordEvent(.disposed(id: -1)) }
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

        XCTAssertTrue(recordedEvents == [
            Recorded(time: 210, value: SignificantEvent.effects(calledWithInitial: TestRequest(identifier: 0, value: "1"))),
            Recorded(time: 210, value: SignificantEvent.subscribed(id: 0)),
            Recorded(time: 210, value: SignificantEvent.effects(calledWithInitial: TestRequest(identifier: 1, value: "2"))),
            Recorded(time: 210, value: SignificantEvent.subscribed(id: 1)),
            Recorded(time: 220, value: SignificantEvent.disposed(id: -1)),
            Recorded(time: 220, value: SignificantEvent.disposed(id: -1)),
            Recorded(time: 220, value: SignificantEvent.disposedSource),
        ] || recordedEvents == [
            Recorded(time: 210, value: SignificantEvent.effects(calledWithInitial: TestRequest(identifier: 1, value: "2"))),
            Recorded(time: 210, value: SignificantEvent.subscribed(id: 1)),
            Recorded(time: 210, value: SignificantEvent.effects(calledWithInitial: TestRequest(identifier: 0, value: "1"))),
            Recorded(time: 210, value: SignificantEvent.subscribed(id: 0)),
            Recorded(time: 220, value: SignificantEvent.disposed(id: -1)),
            Recorded(time: 220, value: SignificantEvent.disposed(id: -1)),
            Recorded(time: 220, value: SignificantEvent.disposedSource),
        ])

        XCTAssertTrue(results.events == [
            next(211, "Got 1"),
            next(211, "Got 2"),
        ] || results.events == [
            next(211, "Got 2"),
            next(211, "Got 1"),
        ])
    }
}

extension Array {
    func indexBy<Key>(_ keySelector: (Element) -> Key) -> [Key: Element] {
        return Dictionary(self.map { (keySelector($0), $0) }, uniquingKeysWith: { first, _ in first })
    }
}

struct TestRequest: Equatable {
    var identifier: Int
    var value: String
}
