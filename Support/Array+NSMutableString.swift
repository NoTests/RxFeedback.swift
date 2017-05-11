//
//  Array+NSMutableString.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 5/11/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//
import class Foundation.NSAttributedString
import class Foundation.NSMutableAttributedString

protocol NSAttributedStringConvertible {
    var attributedString: NSAttributedString {
        get
    }
}

extension Array where Element == NSAttributedStringConvertible {
    func joinedAttributed(separator: NSAttributedStringConvertible) -> NSAttributedString {
        let returnValue = NSMutableAttributedString()

        for element in self {
            returnValue.append(element.attributedString)
        }

        return returnValue
    }
}

extension String: NSAttributedStringConvertible {
    var attributedString: NSAttributedString {
        get {
            return NSAttributedString(string: self)
        }
    }
}

extension NSAttributedString: NSAttributedStringConvertible {
    var attributedString: NSAttributedString {
        return self
    }
}
