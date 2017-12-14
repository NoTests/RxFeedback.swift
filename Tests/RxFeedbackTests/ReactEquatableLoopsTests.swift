//
//  ReactEquatableLoopsTests.swift
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

class ReactEquatableLoopsTests: RxTest {
}

// Tests on the react function with not an equatable or hashable Control.
extension ReactEquatableLoopsTests {

    func testIntialNilQueryDoesNotProduceEffects() {
        // Prepare
        let scheduler = TestScheduler(initialClock: 0)
        let query: (String) -> String? = { _ in
            return nil
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

    func testNotNilAfterIntialNilDoesProduceEffects() {
        // Prepare
        let scheduler = TestScheduler(initialClock: 0)
        let query: (String) -> String? = { state in
            if state == "initial+" {
                return "I"
            } else {
                return nil
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

    func testSecondConsecutiveEqualQueryDoesNotProduceEffects() {
        // Prepare
        let scheduler = TestScheduler(initialClock: 0)
        let query: (String) -> String? = { _ in return "Same" }
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
        let query1: (String) -> String? = { state in
            if state == "initial" {
                return "_I"
            } else {
                return nil
            }
        }
        let query2: (String) -> String? = { state in
            if state == "initial_I_a" {
                return "_IA"
            } else {
                return nil
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

    func testFeedbacksCancelation() {
        // Prepare
        let scheduler = TestScheduler(initialClock: 0)
        let notImmediateEffect = PublishSubject<String>()
        let query1: (String) -> String? = { state in
            if state == "initial" {
                return "_I"
            } else {
                return nil
            }
        }
        let query2: (String) -> String? = { state in
            if state == "initial" {
                return "_I"
            } else {
                return nil
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
}

