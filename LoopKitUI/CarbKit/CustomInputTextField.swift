//
//  CustomInputTextField.swift
//  LoopKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import UIKit

public class CustomInputTextField: UITextField {

    public var customInput: UIInputViewController?

    public override var inputViewController: UIInputViewController? {
        return customInput
    }

}
