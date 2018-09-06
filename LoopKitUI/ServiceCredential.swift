//
//  ServiceCredential.swift
//  Loop
//
//  Created by Nate Racklyeft on 7/2/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit


/// Represents the input method for a service credential
public struct ServiceCredential {
    /// The localized title of the credential (e.g. "Username")
    public let title: String

    /// The localized placeholder text to assist text input
    public let placeholder: String?

    /// Whether the credential is considered secret. Correponds to the `secureTextEntry` trait.
    public let isSecret: Bool

    /// The type of keyboard to use to enter the credential
    public let keyboardType: UIKeyboardType

    /// A set of valid values for presenting a selection. The first item is the default.
    public let options: [(title: String, value: String)]?

    public init(title: String, placeholder: String? = nil, isSecret: Bool, keyboardType: UIKeyboardType = .asciiCapable, options: [(title: String, value: String)]? = nil) {
        self.title = title
        self.placeholder = placeholder
        self.isSecret = isSecret
        self.keyboardType = keyboardType
        self.options = options
    }
}
