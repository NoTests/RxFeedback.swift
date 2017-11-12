//
//  Counter.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 4/30/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import RxFeedback

class CounterViewController: UIViewController {
    @IBOutlet weak var label: UILabel?
    @IBOutlet weak var minus: UIButton?
    @IBOutlet weak var plus: UIButton?

    private let disposeBag = DisposeBag()

    typealias State = Int
    enum Event {
        case increment
        case decrement
    }
    private let reducer: Reducer<State, Event> = {
        let reducer = Reducer<State, Event>()
        reducer.accept(event: .increment) { $0 + 1 }
        reducer.accept(event: .decrement) { $0 - 1 }
        return reducer
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        Observable.system(
            initialState: 0,
            reducer: reducer,
            scheduler: MainScheduler.instance,
            scheduledFeedback:
                // UI is user feedback
                bind(self) { me, state -> Bindings<Event> in
                    let subscriptions = [
                        state.map(String.init).bind(to: me.label!.rx.text)
                    ]
                    let events = [
                        me.plus!.rx.tap.map { Event.increment },
                        me.minus!.rx.tap.map { Event.decrement }
                    ]
                    return Bindings(subscriptions: subscriptions, events: events)
                }
            )
            .subscribe()
            .disposed(by: disposeBag)

    }
}

