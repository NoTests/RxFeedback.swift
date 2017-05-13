//
//  UIView+Extensions.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 4/30/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import RxSwift
import RxCocoa

public struct UI {}

extension UI {

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
        public init(subscriptions: [Disposable], events: [Driver<Event>]) {
            self.subscriptions = subscriptions
            self.events = events.map { $0.asObservable() }
        }

        public func dispose() {
            for subscription in subscriptions {
                subscription.dispose()
            }
        }
    }

    /**
     Bi-directional binding of a system State to UI and UI into Events.
     */
    public static func bind<State, Event>(_ bindings: @escaping (Observable<State>) -> (Bindings<Event>)) -> (Observable<State>) -> Observable<Event> {

        return { (state: Observable<State>) -> Observable<Event> in
            return Observable<Event>.using({ () -> Bindings<Event> in
                return bindings(state)
            }, observableFactory: { (bindings: Bindings<Event>) -> Observable<Event> in
                return Observable<Event>.merge(bindings.events)
            })
        }
    }

    /**
     Bi-directional binding of a system State to UI and UI into Events.
     */
    public static func bind<State, Event>(_ bindings: @escaping (Driver<State>) -> (Bindings<Event>)) -> (Driver<State>) -> Driver<Event> {

        return { (state: Driver<State>) -> Driver<Event> in
            return Observable<Event>.using({ () -> Bindings<Event> in
                return bindings(state)
            }, observableFactory: { (bindings: Bindings<Event>) -> Observable<Event> in
                return Observable<Event>.merge(bindings.events)
            }).asDriver(onErrorDriveWith: Driver.empty())
        }
    }
}

