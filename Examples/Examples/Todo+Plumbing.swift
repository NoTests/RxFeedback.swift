//
//  Todo+Plumbing.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 5/11/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import struct Foundation.UUID
import class Foundation.NSObject

protocol Identifiable {
    associatedtype Identifier: Hashable
    var id: Identifier { get }
}

protocol Syncable {
    var state: SyncState {
        get
    }

    static func setSync(_ state: SyncState) -> (Self) -> Self
}

class Unique: NSObject {
}

struct Version<Value: Identifiable & Syncable>: Identifiable, Syncable, Hashable {

    typealias Identifier = Value.Identifier
    private let _unique: Unique
    let value: Value

    init(_ value: Value) {
        self._unique = Unique()
        self.value = value
    }
    
    var hashValue: Int {
        return self._unique.hash
    }

    var id: Identifier {
        return value.id
    }

    var state: SyncState {
        get {
            return self.value.state
        }
    }

    static func setSync(_ state: SyncState) -> (Version<Value>) -> Version<Value> {
        return self.map(transform: Value.setSync(state))
    }

    static func == (lhs: Version<Value>, rhs: Version<Value>) -> Bool {
        return lhs._unique === rhs._unique
    }
}

extension Task: Identifiable {
    typealias Identifier = UUID
}
