//
//  DecimalTextFieldTableViewCell.swift
//  CarbKit
//
//  Created by Nathan Racklyeft on 1/15/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit


protocol TextFieldTableViewCellDelegate: class {
    func textFieldTableViewCellDidBeginEditing(_ cell: TextFieldTableViewCell)

    func textFieldTableViewCellDidEndEditing(_ cell: TextFieldTableViewCell)
}


class TextFieldTableViewCell: UITableViewCell, UITextFieldDelegate {

    @IBOutlet weak var textField: UITextField! {
        didSet {
            textField.delegate = self
        }
    }

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

    override func layoutSubviews() {
        super.layoutSubviews()

        contentView.layoutMargins.left = separatorInset.left
        contentView.layoutMargins.right = separatorInset.left
    }

    weak var delegate: TextFieldTableViewCellDelegate?

    // MARK: - UITextFieldDelegate

    func textFieldDidBeginEditing(_ textField: UITextField) {
        delegate?.textFieldTableViewCellDidBeginEditing(self)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        delegate?.textFieldTableViewCellDidEndEditing(self)
    }
}


class DecimalTextFieldTableViewCell: TextFieldTableViewCell {

    @IBOutlet weak var unitLabel: UILabel!

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

    override func textFieldDidEndEditing(_ textField: UITextField) {
        if let number = number {
            textField.text = numberFormatter.string(from: number)
        } else {
            textField.text = nil
        }

        super.textFieldDidEndEditing(textField)
    }
}

