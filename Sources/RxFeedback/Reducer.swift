//
//  Reducer.swift
//  RxFeedback
//
//  Created by DTVD on 11/4/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import Foundation

/**
 Reducer class that defines transition rules as a set of type (Event) -> StateMonad<State>.
 */
public class Reducer<State: Equatable, Event: Equatable> {

    typealias Transition = (Event) -> StateMonad<State>
    private var graph: [Transition] = []
    private let identityMonad: StateMonad<State> = StateMonad { s in return s }

    public init() {}

    /**
    Accept individual rule.

     - parameter event: event triggers state transformation.
     - parameter transform: transformation from current state to next state.
     */
    public func accept(event: Event, transform: @escaping (State) -> State) {
        let transition: Transition = { [unowned self] e in
            guard e == event else { return self.identityMonad }
            return StateMonad(f: transform)
        }
        graph.append(transition)
    }

    /**
     Reduce function.
     This will combine all rules and produces a final lambda to decide the next state.
     */
    public lazy var reduce: (State, Event) -> State = { [unowned self] state, event in
        let monad: StateMonad<State> = self.graph
            .map { $0(event) }
            .reduce(self.identityMonad) { lhs, rhs in
                return StateMonad { s in
                    if lhs.run(s: s) != s { return lhs.run(s: s) }
                    if rhs.run(s: s) != s { return rhs.run(s: s) }
                    return s
                }
            }
        return monad.run(s: state)
    }

}


