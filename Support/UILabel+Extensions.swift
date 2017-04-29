//
//  UILabel+Extensions.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 5/1/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

extension Reactive where Base: UILabel {
    var textOrHide: UIBindingObserver<UILabel, String?> {
        return UIBindingObserver(UIElement: base) { label, value in
            guard let value = value else {
                label.isHidden = true
                return
            }

            label.text = value
            label.isHidden = false
        }
    }
}
