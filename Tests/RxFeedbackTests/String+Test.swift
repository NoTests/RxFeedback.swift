//
//  String+Test.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 8/13/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import Foundation

extension String {
    var needsToAppendDot: ()? {
        if self == "initial" || self == "initial_." || self == "initial_._." {
            return ()
        }
        else {
            return nil
        }
    }

    var needsToAppend: String? {
        if self == "initial" {
            return "_a"
        }
        else if self == "initial_a" {
            return "_b"
        }
        else if self == "initial_a_b" {
            return "_c"
        }
        else {
            return nil
        }
    }

    var needsToAppendParallel: Set<String> {
        if self.contains("_a") && self.contains("_b") {
            return Set(["_c"])
        }
        else {
            var result = Set<String>()
            if !self.contains("_a") {
                result.insert("_a")
            }
            if !self.contains("_b") {
                result.insert("_b")
            }
            return result
        }
    }
}
