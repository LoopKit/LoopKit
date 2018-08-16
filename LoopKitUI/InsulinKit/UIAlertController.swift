//
//  UIAlertController.swift
//  InsulinKit
//
//

import UIKit


extension UIAlertController {
    convenience init(deleteAllConfirmationMessage: String, confirmationHandler handler: @escaping () -> Void) {
        self.init(
            title: nil,
            message: deleteAllConfirmationMessage,
            preferredStyle: .actionSheet
        )

        addAction(UIAlertAction(
            title: LocalizedString("Delete All", comment: "Button title to delete all objects"),
            style: .destructive,
            handler: { (_) in
                handler()
            }
        ))

        addAction(UIAlertAction(
            title: LocalizedString("Cancel", comment: "The title of the cancel action in an action sheet"),
            style: .cancel,
            handler: nil
        ))
    }
}
