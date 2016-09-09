//
//  AbsorptionTimeTextFieldTableViewCell.swift
//  CarbKit
//
//  Created by Nathan Racklyeft on 1/15/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit

class AbsorptionTimeTextFieldTableViewCell: DecimalTextFieldTableViewCell {

    override var numberFormatter: NumberFormatter {
        didSet {
            numberFormatter.numberStyle = .none
        }
    }

    var segmentValues: [Double] = []

    var segmentedControlInputAccessoryView: SegmentedControlInputAccessoryView?

    func selectedSegmentChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case let x where x < segmentValues.count:
            textField.text = numberFormatter.string(from: NSNumber(value: segmentValues[x] as Double))
            delegate?.textFieldTableViewCellDidUpdateText(self)
        default:
            break
        }
    }

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        textField.inputAccessoryView = segmentedControlInputAccessoryView

        segmentedControlInputAccessoryView?.segmentedControl?.addTarget(self, action: #selector(selectedSegmentChanged(_:)), for: .valueChanged)

        return true
    }

    override func textFieldDidEndEditing(_ textField: UITextField) {
        super.textFieldDidEndEditing(textField)

        segmentedControlInputAccessoryView?.segmentedControl?.removeTarget(self, action: #selector(selectedSegmentChanged(_:)), for: .valueChanged)
    }

    func textField(_ textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        segmentedControlInputAccessoryView?.segmentedControl?.selectedSegmentIndex = -1

        return true
    }
}
