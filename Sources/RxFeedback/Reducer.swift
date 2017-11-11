//
//  Reducer.swift
//  RxFeedback
//
//  Created by DTVD on 11/4/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import Foundation

public class Reducer<State: Equatable, Event> {

    typealias Transition = (Event) -> StateMonad<State>
    private var graph: [Transition] = []
    private let identity: State
    private let identityMonad: StateMonad<State> = StateMonad { s in return s }
    
    public init(defaultState: State) {
        identity = defaultState
    }

    public func addEdge(input: State, output: State, event: Event) {
        let transition: Transition = { [unowned self] event in
            return StateMonad { s in
                let s1: State = s == input ? output : self.identity
                return s1
            }
        }
        graph.append(transition)
    }

    private var transitionFunction: Transition {
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

    public var reduce: (State, Event) -> State {
        return { [unowned self] state, event in
            return self.transitionFunction(event).run(s: state)
        }
    }

}


