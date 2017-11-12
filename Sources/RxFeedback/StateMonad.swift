//
//  StateMonad.swift
//  RxFeedback
//
//  Created by DTVD on 11/4/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import Foundation

/**
    This is simplest form of State Monad.
    This struct is basically a wrapper for a state transform function (s) -> s
 */
struct StateMonad<S> {
    private let run: (S) -> (S)

    init(f: @escaping (S) -> (S)) {
        self.run = f
    }

    func run(s: S) -> (S) {
        return self.run(s)
    }

}
