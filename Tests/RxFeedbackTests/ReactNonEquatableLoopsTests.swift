//
//  ReactNonEquatableLoopsTests.swift
//  RxFeedback
//
//  Created by Alexander Sokol on 23/09/2017.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import Foundation
import XCTest
import RxFeedback
import RxSwift
import RxTest

class ReactNonNilLoopsTests: RxTest {
}

// Tests on the react function with not an equatable or hashable Control.
extension ReactNonNilLoopsTests {

    func testIntialNilQueryDoesNotProduceEffects() {
        // Prepare
        let scheduler = TestScheduler(initialClock: 0)
        let query: (String) -> ()? = { _ in
            return nil
        }
        let effects: () -> Observable<String> = { .just("_a") }
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
        let query: (String) -> ()? = { state in
            if state == "initial+" {
                return ()
            } else {
                return nil
            }
        }
        let effects: () -> Observable<String> = { .just("_a") }
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
            next(213, "initial+_a"),
            ])
    }

    func testSecondConsecutiveNotNilQueryDoesNotProduceEffects() {
        // Prepare
        let scheduler = TestScheduler(initialClock: 0)
        let query: (String) -> ()? = { _ in return () }
        let effects: () -> Observable<String> = {
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
        let query1: (String) -> ()? = { state in
            if state == "initial" {
                return ()
            } else {
                return nil
            }
        }
        let query2: (String) -> ()? = { state in
            if state == "initial_a" {
                return ()
            } else {
                return nil
            }
        }
        let effects1: () -> Observable<String> = {
            return .just("_a")
        }
        let effects2: () -> Observable<String> = {
            return .just("_b")
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
            next(204, "initial_a"),
            next(206, "initial_a_b")
            ])
    }

    func testFeedbacksCancelation() {
        // Prepare
        let scheduler = TestScheduler(initialClock: 0)
        let notImmediateEffect = PublishSubject<String>()
        let query1: (String) -> ()? = { state in
            if state == "initial" {
                return ()
            } else {
                return nil
            }
        }
        let query2: (String) -> ()? = { state in
            if state == "initial" {
                return ()
            } else {
                return nil
            }
        }
        var isEffects1Called = false
        let effects1: () -> Observable<String> = {
            isEffects1Called = true
            return notImmediateEffect.asObservable()
        }
        let effects2: () -> Observable<String> = {
            return .just("_b")
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
            next(204, "initial_b")
            ])
        XCTAssertTrue(isEffects1Called)
    }
}
