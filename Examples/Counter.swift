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
        enum Event {
            case increment
            case decrement
        }

        let label = self.label!
        let minus = self.minus!
        let plus = self.plus!

        Observable.system(
            initialState: 0,
            reduce: { (state, event) -> State in
                    switch event {
                    case .increment:
                        return state + 1
                    case .decrement:
                        return state - 1
                    }
                },
            scheduler: MainScheduler.instance,
            feedback:
                // UI is user feedback
                UI.bind { state in
                    ([
                        state.map(String.init).bind(to: label.rx.text)
                    ], [
                        plus.rx.tap.map { Event.increment },
                        minus.rx.tap.map { Event.decrement }
                    ])
                }
            )
            .subscribe()
            .disposed(by: disposeBag)

    }
}

