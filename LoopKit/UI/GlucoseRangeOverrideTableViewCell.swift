//
//  GlucoseRangeOverrideTableViewCell.swift
//  LoopKit
//
//  Created by Nate Racklyeft on 7/13/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit


protocol GlucoseRangeOverrideTableViewCellDelegate: class {
    func glucoseRangeOverrideTableViewCellDidUpdateValue(cell: GlucoseRangeOverrideTableViewCell)
}


class GlucoseRangeOverrideTableViewCell: UITableViewCell, UITextFieldDelegate {

    weak var delegate: GlucoseRangeOverrideTableViewCellDelegate?

    var minValue: Double = 0 {
        didSet {
            minValueTextField.text = valueNumberFormatter.stringFromNumber(minValue)
        }
    }

    var maxValue: Double = 0 {
        didSet {
            maxValueTextField.text = valueNumberFormatter.stringFromNumber(maxValue)
        }
    }

    lazy var valueNumberFormatter: NSNumberFormatter = {
        let formatter = NSNumberFormatter()
        formatter.numberStyle = .DecimalStyle
        formatter.minimumFractionDigits = 1

        return formatter
    }()

    var unitString: String? {
        get {
            return unitLabel.text
        }
        set {
            unitLabel.text = newValue
        }
    }

    // MARK: Outlets

    @IBOutlet weak var iconImageView: UIImageView!

    @IBOutlet weak var unitLabel: UILabel!

    @IBOutlet weak var minValueTextField: UITextField!

    @IBOutlet weak var maxValueTextField: UITextField!

    // MARK: - UITextFieldDelegate

    func textFieldDidBeginEditing(textField: UITextField) {
        dispatch_async(dispatch_get_main_queue()) {
            textField.selectedTextRange = textField.textRangeFromPosition(textField.beginningOfDocument, toPosition: textField.endOfDocument)
        }
    }

    func textFieldDidEndEditing(textField: UITextField) {
        let value = valueNumberFormatter.numberFromString(textField.text ?? "")?.doubleValue ?? 0

        switch textField {
        case minValueTextField:
            minValue = value
        case maxValueTextField:
            maxValue = value
        default:
            break
        }

        delegate?.glucoseRangeOverrideTableViewCellDidUpdateValue(self)
    }
}
