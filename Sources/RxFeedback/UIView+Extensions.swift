//
//  UIView+Extensions.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 4/30/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import RxSwift
import RxCocoa

public struct UI {
}

extension UI {
    private class Bindings<Event>: Disposable {
        let subscriptions: [Disposable]
        let events: [Observable<Event>]

        init(subscriptions: [Disposable], events: [Observable<Event>]) {
            self.subscriptions = subscriptions
            self.events = events
        }
        
        func dispose() {
            for subscription in subscriptions {
                subscription.dispose()
            }
        }
    }

    
    public static func bind<State, Event>(_ bindings: @escaping (Observable<State>) -> (subscriptions: [Disposable], events: [Observable<Event>])) -> (Observable<State>) -> Observable<Event> {

        return { (state: Observable<State>) -> Observable<Event> in
            return Observable<Event>.using({ () -> Bindings<Event> in
                let (subscriptions, events) = bindings(state)
                return Bindings<Event>(subscriptions: subscriptions, events: events)
            }, observableFactory: { (bindings: Bindings<Event>) -> Observable<Event> in
                return Observable<Event>.merge(bindings.events)
            })
        }
    }

    public static func bind<State, Event>(_ bindings: @escaping (Driver<State>) -> (subscriptions: [Disposable], events: [Driver<Event>])) -> (Driver<State>) -> Driver<Event> {

        return { (state: Driver<State>) -> Driver<Event> in
            return Observable<Event>.using({ () -> Bindings<Event> in
                let (subscriptions, events) = bindings(state)
                return Bindings<Event>(subscriptions: subscriptions, events: events.map { $0.asObservable() })
            }, observableFactory: { (bindings: Bindings<Event>) -> Observable<Event> in
                return Observable<Event>.merge(bindings.events)
            }).asDriver(onErrorDriveWith: Driver.empty())
        }
    }
}

