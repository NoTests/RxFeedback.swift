//
//  Safe.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 5/11/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import Foundation

func tryOrReturn<R>(_ fallback: R, calculate: () throws -> R) -> R {
    do {
        return try calculate()
    }
    catch let e {
        print(e) // better error handling is needed, this is just an example
        return fallback
    }
}
