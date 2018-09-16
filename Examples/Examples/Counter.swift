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
    
    override func viewDidLoad() {
        super.viewDidLoad()

        typealias State = Int

        enum Mutation {
            case increment
            case decrement
        }

        Observable.system(
            initialState: 0,
            reduce: { (state, mutation) -> State in
                switch mutation {
                case .increment:
                    return state + 1
                case .decrement:
                    return state - 1
                }
        },
            scheduler: MainScheduler.instance,
            scheduledFeedback:
                // UI is user feedback
                bind(self) { me, state -> Bindings<Mutation> in
                    let subscriptions = [
                        state.map(String.init).bind(to: me.label!.rx.text)
                    ]

                    let mutations = [
                        me.plus!.rx.tap.map { Mutation.increment },
                        me.minus!.rx.tap.map { Mutation.decrement }
                    ]

                    return Bindings(subscriptions: subscriptions,
                                    mutations: mutations)
                }
            )
            .subscribe()
            .disposed(by: disposeBag)

    }
}

