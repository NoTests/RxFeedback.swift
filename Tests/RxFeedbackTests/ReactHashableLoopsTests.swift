//
//  ReactHashableLoopsTests.swift
//  RxFeedbackTests
//
//  Created by Krunoslav Zaher on 11/7/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import Foundation
import XCTest
import RxFeedback
import RxSwift
import RxTest

class ReactHashableLoopsTests: RxTest {
}

// Tests on the react function with not an equatable or hashable Control.
extension ReactHashableLoopsTests {

    func testEmptyQueryDoesNotProduceEffects() {
        // Prepare
        let scheduler = TestScheduler(initialClock: 0)
        let query: (String) -> Set<String> = { _ in
            return Set()
        }
        let effects: (String) -> Observable<String> = { .just($0 + "_a") }
        let feedback: (ObservableSchedulerContext<String>) -> Observable<String> = react(query: query, effects: effects)
        let system = Observable.system(
            initialState: "initial",
            reduce: { oldState, append in
                return  oldState + append
        },
            scheduler: scheduler,
            scheduledFeedback: feedback
        )

        // Run
        let results = scheduler.start { system }

        // Test
        XCTAssertEqual(results.events, [
            next(201, "initial")
            ])
    }

    func testNonEmptyAfterEmptyDoesProduceEffects() {
        // Prepare
        let scheduler = TestScheduler(initialClock: 0)
        let query: (String) -> Set<String> = { state in
            if state == "initial+" {
                return Set(["I"])
            } else {
                return Set()
            }
        }
        let effects: (String) -> Observable<String> = { .just($0 + "_a") }
        let feedback: (ObservableSchedulerContext<String>) -> Observable<String> = react(query: query, effects: effects)
        let events = PublishSubject<String>()
        let system = Observable.system(
            initialState: "initial",
            reduce: { oldState, append in
                return  oldState + append
        },
            scheduler: scheduler,
            scheduledFeedback: feedback, { _ in events.asObservable() }
        )

        // Run
        scheduler.scheduleAt(210) { events.onNext("+") }
        let results = scheduler.start { system }

        // Test
        XCTAssertEqual(results.events, [
            next(201, "initial"),
            next(211, "initial+"),
            next(213, "initial+I_a"),
            ])
    }

    func testEqualQueryDoesNotProduceEffects() {
        // Prepare
        let scheduler = TestScheduler(initialClock: 0)
        let query: (String) -> Set<String> = { _ in return Set(["Same"]) }
        let effects: (String) -> Observable<String> = { _ in
            return .just("_a")
        }
        let feedback: (ObservableSchedulerContext<String>) -> Observable<String> = react(query: query, effects: effects)
        let system = Observable.system(
            initialState: "initial",
            reduce: { oldState, append in
                return  oldState + append
        },
            scheduler: scheduler,
            scheduledFeedback: feedback
        )

        // Run
        let results = scheduler.start { system }

        // Test
        XCTAssertEqual(results.events, [
            next(201, "initial"),
            next(204, "initial_a")
            ])
    }

    func testImmediateEffectsHaveTheSameOrderAsTheyArePassedToSystem() {
        // Prepare
        let scheduler = TestScheduler(initialClock: 0)
        let query1: (String) -> Set<String> = { state in
            if state == "initial" {
                return Set(["_I"])
            } else {
                return Set()
            }
        }
        let query2: (String) -> Set<String> = { state in
            if state == "initial_I_a" {
                return Set(["_IA"])
            } else {
                return Set()
            }
        }
        let effects1: (String) -> Observable<String> = {
            return .just($0 + "_a")
        }
        let effects2: (String) -> Observable<String> = {
            return .just($0 + "_b")
        }
        let feedback1: (ObservableSchedulerContext<String>) -> Observable<String>
        feedback1 = react(query: query1, effects: effects1)
        let feedback2: (ObservableSchedulerContext<String>) -> Observable<String>
        feedback2 = react(query: query2, effects: effects2)
        let system = Observable.system(
            initialState: "initial",
            reduce: { oldState, append in
                return  oldState + append
        },
            scheduler: scheduler,
            scheduledFeedback: feedback1, feedback2
        )

        // Run
        let results = scheduler.start { system }

        // Test
        XCTAssertEqual(results.events, [
            next(201, "initial"),
            next(204, "initial_I_a"),
            next(206, "initial_I_a_IA_b")
            ])
    }

    func testFeedbacksCancelationBetweenLoops() {
        // Prepare
        let scheduler = TestScheduler(initialClock: 0)
        let notImmediateEffect = PublishSubject<String>()
        let query1: (String) -> Set<String> = { state in
            if state == "initial" {
                return Set(["_I"])
            } else {
                return Set()
            }
        }
        let query2: (String) -> Set<String> = { state in
            if state == "initial" {
                return Set(["_I"])
            } else {
                return Set()
            }
        }
        var isEffects1Called = false
        let effects1: (String) -> Observable<String> = { _ in
            isEffects1Called = true
            return notImmediateEffect.asObservable()
        }
        let effects2: (String) -> Observable<String> = {
            return .just($0 + "_b")
        }
        let feedback1: (ObservableSchedulerContext<String>) -> Observable<String>
        feedback1 = react(query: query1, effects: effects1)
        let feedback2: (ObservableSchedulerContext<String>) -> Observable<String>
        feedback2 = react(query: query2, effects: effects2)
        let system = Observable.system(
            initialState: "initial",
            reduce: { oldState, append in
                return  oldState + append
        },
            scheduler: scheduler,
            scheduledFeedback: feedback1, feedback2
        )

        // Run
        scheduler.scheduleAt(210) { notImmediateEffect.onNext("_a") }
        let results = scheduler.start { system }

        // Test
        XCTAssertEqual(results.events, [
            next(201, "initial"),
            next(204, "initial_I_b")
            ])
        XCTAssertTrue(isEffects1Called)
    }

    func testFeedbacksCancelationInsideLoop() {
        // Prepare
        let scheduler = TestScheduler(initialClock: 0)
        let initiator = PublishSubject<String>()
        let query: (String) -> Set<String> = { state in
            if state == "initial" {
                return Set(["_I", "_I2", "_I3", "_I4"])
            } else {
                return Set()
            }
        }
        var isEffects1Called = false
        let effects: (String) -> Observable<String> = { query in
            if query == "_I" {
                return Observable.just(query + "_done")
                    .delay(20.0, scheduler: scheduler)
            } else if query == "_I2" {
                isEffects1Called = true
                return Observable.just(query + "_done")
                    .delay(30.0, scheduler: scheduler)
            } else if query == "_I3" {
                isEffects1Called = true
                return Observable.just(query + "_done")
                    .delay(30.0, scheduler: scheduler)
            } else if query == "_I4" {
                isEffects1Called = true
                return Observable.just(query + "_done")
                    .delay(30.0, scheduler: scheduler)
            } else {
                fatalError()
            }
        }
        let system = Observable.system(
            initialState: "",
            reduce: { oldState, append in
                return  oldState + append
        },
            scheduler: scheduler,
            scheduledFeedback: react(query: query, effects: effects),
            { _ in initiator.asObservable() }
        )

        #if DEBUG
            var resourceCount = Resources.total
        #endif

        // Run
        // warming up current thread scheduler
        scheduler.scheduleAt(210) {
            initiator.onNext("")
        }

        scheduler.scheduleAt(215) {
            #if DEBUG
                resourceCount = Resources.total
            #endif
            initiator.onNext("initial")
            scheduler.maintainResourceCount()
        }
        #if DEBUG
            scheduler.scheduleAt(250) {
                XCTAssertEqual(resourceCount, Resources.total)
                scheduler.maintainResourceCount()
            }
        #endif
        
        let results = scheduler.start { system }

        // Test
        XCTAssertEqual(results.events, [
            next(201, ""),
            next(211, ""),
            next(216, "initial"),
            next(238, "initial_I_done"),
            ])
        XCTAssertTrue(isEffects1Called)
    }

    func testFeedbacksDoesntCancelInsideLoopWhenNewStateIsEmittedThatAlsoHasTheSameQuery() {
        // Prepare
        let scheduler = TestScheduler(initialClock: 0)
        let initiator = PublishSubject<String>()
        let query: (String) -> Set<String> = { state in
            if state == "initial" {
                return Set(["_I", "_I2"])
            } else if state == "initial_I_done" {
                return Set(["_I2"])
            } else {
                return Set()
            }
        }
        let effects: (String) -> Observable<String> = { query in
            if query == "_I" {
                return Observable.just(query + "_done")
                    .delay(20.0, scheduler: scheduler)
            } else if query == "_I2" {
                return Observable.just(query + "_done")
                    .delay(30.0, scheduler: scheduler)
            } else {
                fatalError()
            }
        }
        let system = Observable.system(
            initialState: "",
            reduce: { oldState, append in
                return  oldState + append
        },
            scheduler: scheduler,
            scheduledFeedback: react(query: query, effects: effects),
            { _ in initiator.asObservable() }
        )

        #if DEBUG
            var resourceCount = Resources.total
        #endif

        // Run
        // warming up current thread scheduler
        scheduler.scheduleAt(210) {
            initiator.onNext("")
        }
        scheduler.scheduleAt(215) {
            #if DEBUG
                resourceCount = Resources.total
            #endif
            initiator.onNext("initial")
            scheduler.maintainResourceCount()
        }
        #if DEBUG
            scheduler.scheduleAt(280) { XCTAssertEqual(resourceCount, Resources.total) }
        #endif
        let results = scheduler.start { system }

        // Test
        XCTAssertEqual(results.events, [
            next(201, ""),
            next(211, ""),
            next(216, "initial"),
            next(238, "initial_I_done"),
            next(248, "initial_I_done_I2_done"),
            ])
    }
}

extension TestScheduler {
    fileprivate func maintainResourceCount() {
        self.scheduleAt(2000, action: { })
    }
}
