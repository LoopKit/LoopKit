//
//  CustomInputTextField.swift
//  LoopKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import UIKit

class CustomInputTextField: UITextField {

    var customInput: UIInputViewController?

    override var inputViewController: UIInputViewController? {
        return customInput
    }

}
