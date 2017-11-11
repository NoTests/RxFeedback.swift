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

    public func addEdge(event: Event, transform: @escaping (State) -> State) {
        let transition: Transition = { event in
            return StateMonad(f: transform)
        }
        graph.append(transition)
    }

    public var reduce: (State, Event) -> State {
        return { [unowned self] state, event in
            let monad: StateMonad<State> = self.graph
                .map { $0(event) }
                .reduce(self.identityMonad) { lhs, rhs in
                    return StateMonad { [unowned self] s in
                        if lhs.run(s: s) != self.identity { return lhs.run(s: s) }
                        if rhs.run(s: s) != self.identity { return rhs.run(s: s) }
                        return self.identity
                    }
                }
            return monad.run(s: state)
        }
    }

}


