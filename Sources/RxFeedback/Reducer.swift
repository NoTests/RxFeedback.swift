//
//  Reducer.swift
//  RxFeedback
//
//  Created by DTVD on 11/4/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import Foundation

class Reducer<State: Equatable, Event> {

    typealias Transition = (Event) -> StateMonad<State>
    private var graph: [Transition] = []
    private let identity: State
    private let identityMonad: StateMonad<State> = StateMonad { s in return s }
    
    init(defaultState: State) {
        identity = defaultState
    }

    func addEdge(input: State, output: State, event: Event) {
        let transition: Transition = { [unowned self] event in
            return StateMonad { s in
                let s1: State = s == input ? output : self.identity
                return s1
            }
        }
        graph.append(transition)
    }

    var reduce: Transition {
        return { [unowned self] e in
            return self.graph
                .map { $0(e) }
                .reduce(self.identityMonad) { lhs, rhs in
                    return StateMonad { [unowned self] s in
                        if lhs.run(s: s) != self.identity { return lhs.run(s: s) }
                        if rhs.run(s: s) != self.identity { return rhs.run(s: s) }
                        return self.identity
                    }
                }
        }
    }

}


