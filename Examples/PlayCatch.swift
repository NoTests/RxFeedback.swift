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


fileprivate enum State {
    case humanHasIt
    case machineHasIt
}

fileprivate enum Event {
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

        let myLabel = self.myLabel!
        let machinesLabel = self.machinesLabel!
        let throwTheBallButton = self.throwTheBallButton!

        let bindUI: (Observable<State>) -> Observable<Event> = UI.bind { state in (
            [
                state.map { $0.myStateOfMind }.bind(to: myLabel.rx.text),
                state.map { $0.machineStateOfMind }.bind(to: machinesLabel.rx.text),
                state.map { !$0.doIHaveTheBall }.bind(to: throwTheBallButton.rx.isHidden),
            ], [
                throwTheBallButton.rx.tap.map { Event.throwToMachine }
            ]
        )}

        Observable.system(
            initialState: State.humanHasIt,
            reduce: { (state: State, event: Event) -> State in
                switch event {
                    case .throwToMachine:
                        return .machineHasIt
                    case .throwToHuman:
                        return .humanHasIt
                    }
                },
            scheduler: MainScheduler.instance,
            feedback:
                // UI is human feedback
                bindUI,
                // NoUI, machine feedback
                react(query: { $0.machinePitching }, effects: { () -> Observable<Event> in
                    return Observable<Int>
                        .timer(1.0, scheduler: MainScheduler.instance)
                        .map { _ in Event.throwToHuman }
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
