//
//  UITableView+Rx.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 5/13/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

extension Reactive where Base: UITableView {
    var isEditing: UIBindingObserver<UITableView, Bool> {
        return UIBindingObserver(UIElement: base) { (tableView, isEditing) in
            tableView.isEditing = isEditing
        }
    }
}
