//
//  ControlEvent+Signal.swift
//  Example
//
//  Created by Krunoslav Zaher on 10/18/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import RxCocoa

extension ControlEvent {
    func asSignal() -> Signal<E> {
        return self.asObservable().asSignal(onErrorSignalWith: .empty())
    }
}

