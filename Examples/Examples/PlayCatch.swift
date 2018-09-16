//
//  PlayCatch.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 5/1/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import RxFeedback


private enum State {
    case humanHasIt
    case machineHasIt
}

private enum Mutation {
    case throwToMachine
    case throwToHuman
}

class PlayCatchViewController: UIViewController {
    @IBOutlet weak var myLabel: UILabel?
    @IBOutlet weak var machinesLabel: UILabel?
    @IBOutlet weak var throwTheBallButton: UIButton?

    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let bindUI: (ObservableSchedulerContext<State>) -> Observable<Mutation> = bind(self) { me, state in
            let subscriptions = [
                state.map { $0.myStateOfMind }.bind(to: me.myLabel!.rx.text),
                state.map { $0.machineStateOfMind }.bind(to: me.machinesLabel!.rx.text),
                state.map { !$0.doIHaveTheBall }.bind(to: me.throwTheBallButton!.rx.isHidden),
            ]

            let mutations = [
                me.throwTheBallButton!.rx.tap.map { Mutation.throwToMachine }
            ]

            return Bindings(subscriptions: subscriptions, mutations: mutations)
        }

        Observable.system(
            initialState: State.humanHasIt,
            reduce: { (state: State, mutation: Mutation) -> State in
                switch mutation {
                case .throwToMachine:
                    return .machineHasIt
                case .throwToHuman:
                    return .humanHasIt
                }
        },
            scheduler: MainScheduler.instance,
            scheduledFeedback:
                // UI is human feedback
                bindUI,
                // NoUI, machine feedback
                react(query: { $0.machinePitching }, effects: { () -> Observable<Mutation> in
                    return Observable<Int>
                        .timer(1.0, scheduler: MainScheduler.instance)
                        .map { _ in Mutation.throwToHuman }
                })
        )
        .subscribe()
        .disposed(by: disposeBag)
    }
}

extension State {
    var myStateOfMind: String {
        switch self {
        case .humanHasIt:
            return "I have the 🏈"
        case .machineHasIt:
            return "I'm ready, hit me"
        }
    }

    var doIHaveTheBall: Bool {
        switch self {
        case .humanHasIt:
            return true
        case .machineHasIt:
            return false
        }
    }

    var machineStateOfMind: String {
        switch self {
        case .humanHasIt:
            return "I'm ready, hit me"
        case .machineHasIt:
            return "I have the 🏈"
        }
    }

    var machinePitching: ()? {
        return self == .machineHasIt ? () : nil
    }
}
