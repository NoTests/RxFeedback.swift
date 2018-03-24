//
//  RxFeedbackObservableTests.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 8/13/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import Foundation
import XCTest
import RxFeedback
import RxSwift
import RxBlocking

class RxFeedbackObservableTests: RxTest {
}

extension RxFeedbackObservableTests {
    func testEventsAreArrivingOnCorrectScheduler() {
        let scheduler = SerialDispatchQueueScheduler(qos: .userInitiated)
        let system = Observable.system(
            initialState: "initial",
            reduce: { oldState, append in
                return oldState + "_" + append
            },
            scheduler: scheduler,
            scheduledFeedback: { _ in .just("a") })

        let results = try! system
            .take(2)
            .do(onNext: { _ in
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
                return newState
            },
            scheduler: MainScheduler.instance,
            scheduledFeedback: [])

        var state = ""
        _ = system.subscribe(onNext: { nextState in
            state = nextState
        })

        XCTAssertEqual(state, "initial")
    }

    func testImmediateFeedbackLoop() {
        let system = Observable.system(
            initialState: "initial",
            reduce: { oldState, append in
                return  oldState + append
        },
            scheduler: MainScheduler.instance,
            scheduledFeedback: { stateAndScheduler in
                return stateAndScheduler.flatMap { state -> Observable<String> in
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

        let result = (try?
            system
            .take(4)
            .timeout(0.5, other: Observable.empty(), scheduler: MainScheduler.instance)
            .toBlocking(timeout: 3.0)
                .toArray()
        ) ?? []

        XCTAssertEqual(result, [
            "initial",
            "initial_a",
            "initial_a_b",
            "initial_a_b_c"
            ])
    }

    func testImmediateFeedbackLoopParallel() {
        let feedbackLoop: (ObservableSchedulerContext<String>) -> Observable<String> = { stateAndScheduler in
            return stateAndScheduler.flatMap { state -> Observable<String> in
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
                return  oldState + append
        },
            scheduler: MainScheduler.instance,
            scheduledFeedback: feedbackLoop, feedbackLoop, feedbackLoop)

        let result = (try?
            system
                .asObservable()
                .timeout(0.5, other: Observable.empty(), scheduler: MainScheduler.instance)
                .toBlocking(timeout: 3.0)
                .toArray()
            ) ?? []

        XCTAssertEqual(result, [
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
                return  oldState + append
        },
            scheduler: MainScheduler.instance,
            scheduledFeedback: feedbackLoop, feedbackLoop, feedbackLoop)

        let result = (try?
            system
                .asObservable()
                .timeout(0.5, other: Observable.empty(), scheduler: MainScheduler.instance)
                .toBlocking(timeout: 3.0)
                .toArray()
            ) ?? []

        XCTAssertEqual(result, [
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
                return  oldState + append
        },
            scheduler: MainScheduler.instance,
            scheduledFeedback: feedbackLoop, feedbackLoop, feedbackLoop)

        let result = (try?
            system
                .asObservable()
                .timeout(0.5, other: Observable.empty(), scheduler: MainScheduler.instance)
                .toBlocking(timeout: 3.0)
                .toArray()
            ) ?? []

        XCTAssertEqual(result, [
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
                return  oldState + append
        },
            scheduler: MainScheduler.instance,
            scheduledFeedback: feedbackLoop, feedbackLoop, feedbackLoop)

        let result = (try?
            system
                .asObservable()
                .timeout(0.5, other: Observable.empty(), scheduler: MainScheduler.instance)
                .toBlocking(timeout: 3.0)
                .toArray()
            ) ?? []

        XCTAssertTrue(result[1].contains("_a") || result[1].contains("_b"))
        XCTAssertTrue(result[2].contains("_a") || result[2].contains("_b"))
        XCTAssertTrue(result[1].contains("_a") || result[2].contains("_a"))
        XCTAssertTrue(result[1].contains("_b") || result[2].contains("_b"))

        var ignoringAB = result

        for i in 0 ..< result.count {
            ignoringAB[i] = ignoringAB[i].replacingOccurrences(of: "_a", with: "_x")
            ignoringAB[i] = ignoringAB[i].replacingOccurrences(of: "_b", with: "_x")
        }
        
        XCTAssertEqual(ignoringAB, [
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
                return  oldState + append
            },
            scheduler: MainScheduler.instance,
            scheduledFeedback: RxFeedback.bind { (stateAndScheduler) in
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
                return Bindings(subscriptions: [], events: [results])
        })

        let result = (try?
            system
                .take(4)
                .timeout(0.5, other: Observable.empty(), scheduler: MainScheduler.instance)
                .toBlocking(timeout: 3.0)
                .toArray()
            ) ?? []

        XCTAssertEqual(result, [
            "initial",
            "initial_a",
            "initial_a_b",
            "initial_a_b_c"
            ])
    }

    func testUIBindFeedbackWithOwnerLoopReentrancy() {
        let owner = NSObject()

        let system = Observable.system(
            initialState: "initial",
            reduce: { oldState, append in
                return  oldState + append
            },
            scheduler: MainScheduler.instance,
            scheduledFeedback: RxFeedback.bind(owner) { (_, stateAndScheduler) in
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
                return Bindings(subscriptions: [], events: [results])
        })

        let result = (try?
            system
                .take(4)
                .timeout(0.5, other: Observable.empty(), scheduler: MainScheduler.instance)
                .toBlocking(timeout: 3.0)
                .toArray()
            ) ?? []

        XCTAssertEqual(result, [
            "initial",
            "initial_a",
            "initial_a_b",
            "initial_a_b_c"
            ])
    }

    func testUIBindingsAreNotDisposedWhenNoEventsAreSpecified() {
        typealias State = Int
        typealias Event = Int
        typealias Feedback = (ObservableSchedulerContext<State>) -> Observable<Event>

        var subscriptionState: [Int] = []

        let player: Feedback = react(query: { $0 }, effects: { state in
            return Observable<Int>.timer(0.05, scheduler: MainScheduler.instance).map { _ in 1 }
        })

        let uiBindings: Feedback = bind { state in
            let subscriptions: [Disposable] = [
                state.subscribe(onNext:{ subscriptionState.append($0) })
            ]
            return Bindings(subscriptions: subscriptions, events: [Observable<Event>]())
        }
        let system = Observable.system(
            initialState: 0,
            reduce: { oldState, append in
                return  min(oldState + append, 4)
            },
            scheduler: MainScheduler.instance,
            scheduledFeedback: uiBindings, player
        )

        let result =
            (try? system
                .take(4)
                .timeout(0.5, other: Observable.empty(), scheduler: MainScheduler.instance)
                .toBlocking(timeout: 3.0)
                .toArray()
            ) ?? []

        XCTAssertEqual(subscriptionState, result)
    }
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
