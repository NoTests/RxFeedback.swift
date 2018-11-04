//
//  Identifiable.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 11/4/18.
//  Copyright © 2018 Krunoslav Zaher. All rights reserved.
//

public protocol Identifiable {
    associatedtype Identity: Hashable

    var identifier: Identity { get }
}

