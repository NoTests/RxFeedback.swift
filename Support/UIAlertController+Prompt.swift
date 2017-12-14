//
//  UIAlertController+Prompt.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 5/11/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import UIKit
import RxSwift

public protocol ActionConvertible: CustomStringConvertible {
    var style: UIAlertActionStyle { get }
}

extension UIAlertController {
    public static func prompt<T: ActionConvertible>(message: String, title: String?, actions: [T], parent: UIViewController, type: UIAlertControllerStyle = .alert, configure: @escaping (UIAlertController) -> () = { _ in }) -> Observable<(UIAlertController, T)> {
        return Observable.create { observer in
            let promptController = UIAlertController(title: title, message: message, preferredStyle: type)
            for action in actions {
                let action = UIAlertAction(title: action.description, style: action.style, handler: { [weak promptController] alertAction -> Void in
                    guard let controller = promptController else {
                        return
                    }
                    observer.on(.next((controller, action)))
                    observer.on(.completed)
                })
                promptController.addAction(action)
            }

            configure(promptController)

            parent.present(promptController, animated: true, completion: nil)

            return Disposables.create()
        }
    }
}

public enum AlertAction {
    case ok
    case cancel
    case delete
    case confirm
}

extension AlertAction : ActionConvertible {
    public var description: String {
        switch self {
        case .ok:
            return NSLocalizedString("OK", comment: "Ok action for the alert controller")
        case .cancel:
            return NSLocalizedString("Cancel", comment: "Cancel action for the alert controller")
        case .delete:
            return NSLocalizedString("Delete", comment: "Delete action for the alert controller")
        case .confirm:
            return NSLocalizedString("Confirm", comment: "Confirm action for the alert controller")
        }
    }

    public var style: UIAlertActionStyle {
        switch self {
        case .ok:
            return .`default`
        case .cancel:
            return .cancel
        case .delete:
            return .destructive
        case .confirm:
            return .`default`
        }
    }
}
