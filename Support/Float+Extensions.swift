//
//  Float+Extensions.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 5/13/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import Foundation

extension Double {
    static func random(min: Double, max: Double) -> Double {
        return min + (Double(arc4random_uniform(100000)) / 100000.0) * (max - min)
    }
}
