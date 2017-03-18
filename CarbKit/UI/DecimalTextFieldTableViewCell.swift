//
//  DecimalTextFieldTableViewCell.swift
//  CarbKit
//
//  Created by Nathan Racklyeft on 1/15/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit


protocol TextFieldTableViewCellDelegate: class {
    func textFieldTableViewCellDidUpdateText(_ cell: DecimalTextFieldTableViewCell)
}


class DecimalTextFieldTableViewCell: UITableViewCell, UITextFieldDelegate {

    @IBOutlet weak var textField: UITextField! {
        didSet {
            textField.delegate = self
        }
    }

    @IBOutlet weak var unitLabel: UILabel!

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: true)

        if selected {
            if textField.isFirstResponder {
                textField.resignFirstResponder()
            } else {
                textField.becomeFirstResponder()
            }
        }
    }

    weak var delegate: TextFieldTableViewCellDelegate?

    var numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        return formatter
    }()

    var number: NSNumber? {
        get {
            return numberFormatter.number(from: textField.text ?? "")
        }
        set {
            if let value = newValue {
                textField.text = numberFormatter.string(from: value)
            } else {
                textField.text = nil
            }
        }
    }

    // MARK: - UITextFieldDelegate

    func textFieldDidEndEditing(_ textField: UITextField) {
        if let number = number {
            textField.text = numberFormatter.string(from: number)
        } else {
            textField.text = nil
        }

        delegate?.textFieldTableViewCellDidUpdateText(self)
    }
}

