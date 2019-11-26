//
//  LabeledTextFieldTableViewCell.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 1/3/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import UIKit


public class LabeledTextFieldTableViewCell: TextFieldTableViewCell {
    @IBOutlet public weak var titleLabel: UILabel!

    private var customInputTextField: CustomInputTextField? {
        return textField as? CustomInputTextField
    }

    public var customInput: UIInputViewController? {
        get {
            return customInputTextField?.customInput
        }
        set {
            customInputTextField?.customInput = newValue
        }
    }
}
