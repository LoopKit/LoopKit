//
//  DoubleRangeTableViewCell.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 1/3/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import UIKit
import LoopKit


protocol DoubleRangeTableViewCellDelegate: AnyObject {
    func doubleRangeTableViewCellDidBeginEditing(_ cell: DoubleRangeTableViewCell)
    func doubleRangeTableViewCellDidUpdateRange(_ cell: DoubleRangeTableViewCell)
}


class DoubleRangeTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!

    @IBOutlet weak var minValueTextField: PaddedTextField! {
        didSet {
            minValueTextField.delegate = self
            minValueTextField.addTarget(self, action: #selector(textFieldEditingChanged), for: .editingChanged)
        }
    }

    @IBOutlet weak var maxValueTextField: PaddedTextField! {
        didSet {
            maxValueTextField.delegate = self
            maxValueTextField.addTarget(self, action: #selector(textFieldEditingChanged), for: .editingChanged)
        }
    }

    @IBOutlet weak var unitLabel: UILabel!

    var numberFormatter = NumberFormatter()

    var range: DoubleRange? {
        get {
            guard
                let minValueString = minValueTextField.text,
                let minValue = numberFormatter.number(from: minValueString)?.doubleValue,
                let maxValueString = maxValueTextField.text,
                let maxValue = numberFormatter.number(from: maxValueString)?.doubleValue
            else {
                return nil
            }

            return DoubleRange(minValue: minValue, maxValue: maxValue)
        }
        set {
            guard let newValue = newValue else {
                minValueTextField.text = nil
                maxValueTextField.text = nil
                return
            }
            minValueTextField.text = numberFormatter.string(from: newValue.minValue)
            maxValueTextField.text = numberFormatter.string(from: newValue.maxValue)
        }
    }

    weak var delegate: DoubleRangeTableViewCellDelegate?

    @objc private func textFieldEditingChanged() {
        delegate?.doubleRangeTableViewCellDidUpdateRange(self)
    }
}

extension DoubleRangeTableViewCell: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        delegate?.doubleRangeTableViewCellDidBeginEditing(self)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        delegate?.doubleRangeTableViewCellDidUpdateRange(self)
    }
}
