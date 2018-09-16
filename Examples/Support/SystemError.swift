//
//  SystemError.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 5/1/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

struct SystemError: Error {
    let message: String
    let file: StaticString
    let line: UInt
    init(_ message: String, file: StaticString = #file, line: UInt = #line) {
        self.message = message
        self.file = file
        self.line = line
    }
}
