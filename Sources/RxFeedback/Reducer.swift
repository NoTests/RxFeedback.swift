//
//  Reducer.swift
//  RxFeedback
//
//  Created by DTVD on 11/4/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import Foundation

public class Reducer<State: Equatable, Event: Equatable> {

    typealias Transition = (Event) -> StateMonad<State>
    private var graph: [Transition] = []
    private let identityMonad: StateMonad<State> = StateMonad { s in return s }

    public init() {}

    public func addEdge(event: Event, transform: @escaping (State) -> State) {
        let transition: Transition = { [unowned self] e in
            guard e == event else { return self.identityMonad }
            return StateMonad(f: transform)
        }
        graph.append(transition)
    }

    public lazy var reduce: (State, Event) -> State = { [unowned self] state, event in
        let monad: StateMonad<State> = self.graph
            .map { $0(event) }
            .reduce(self.identityMonad) { lhs, rhs in
                return StateMonad { s in
                    if lhs.run(s: s) != state { return lhs.run(s: s) }
                    if rhs.run(s: s) != state { return rhs.run(s: s) }
                    return state
                }
            }
        return monad.run(s: state)
    }

}


