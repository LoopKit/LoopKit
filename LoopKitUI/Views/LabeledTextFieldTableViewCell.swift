//
//  LabeledTextFieldTableViewCell.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 1/3/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import UIKit


class LabeledTextFieldTableViewCell: TextFieldTableViewCell {
    @IBOutlet weak var titleLabel: UILabel!

    private var customInputTextField: CustomInputTextField? {
        return textField as? CustomInputTextField
    }

    var customInput: UIInputViewController? {
        get {
            return customInputTextField?.customInput
        }
        set {
            customInputTextField?.customInput = newValue
        }
    }
}
