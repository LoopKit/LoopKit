//
//  GlucoseRangeOverrideTableViewCell.swift
//  LoopKit
//
//  Created by Nate Racklyeft on 7/13/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit


protocol GlucoseRangeOverrideTableViewCellDelegate: class {
    func glucoseRangeOverrideTableViewCellDidUpdateValue(_ cell: GlucoseRangeOverrideTableViewCell)
}


class GlucoseRangeOverrideTableViewCell: UITableViewCell, UITextFieldDelegate {

    weak var delegate: GlucoseRangeOverrideTableViewCellDelegate?

    var minValue: Double = 0 {
        didSet {
            minValueTextField.text = valueNumberFormatter.string(from: minValue)
        }
    }

    var maxValue: Double = 0 {
        didSet {
            maxValueTextField.text = valueNumberFormatter.string(from: maxValue)
        }
    }

    lazy var valueNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
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

    @IBOutlet weak var titleLabel: UILabel!

    @IBOutlet weak var unitLabel: UILabel!

    @IBOutlet weak var minValueTextField: UITextField!

    @IBOutlet weak var maxValueTextField: UITextField!

    // MARK: - UITextFieldDelegate

    func textFieldDidBeginEditing(_ textField: UITextField) {
        DispatchQueue.main.async {
            textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        let value = valueNumberFormatter.number(from: textField.text ?? "")?.doubleValue ?? 0

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
