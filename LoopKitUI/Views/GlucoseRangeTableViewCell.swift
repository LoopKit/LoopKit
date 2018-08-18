//
//  GlucoseRangeTableViewCell.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/13/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit


class GlucoseRangeTableViewCell: RepeatingScheduleValueTableViewCell {

    var minValue: Double = 0 {
        didSet {
            minValueTextField.text = valueNumberFormatter.string(from: minValue)
        }
    }

    @IBOutlet weak var minValueTextField: UITextField!

    // MARK: - UITextFieldDelegate

    override func textFieldDidEndEditing(_ textField: UITextField) {
        if textField === minValueTextField {
            minValue = valueNumberFormatter.number(from: textField.text ?? "")?.doubleValue ?? 0
            delegate?.repeatingScheduleValueTableViewCellDidUpdateValue(self)
        } else {
            super.textFieldDidEndEditing(textField)
        }
    }

}
