//
//  DecimalTextFieldTableViewCell.swift
//  CarbKit
//
//  Created by Nathan Racklyeft on 1/15/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit

class CarbDecimalTextFieldTableViewCell: TextFieldTableViewCell {

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

class ProteinDecimalTextFieldTableViewCell: TextFieldTableViewCell {
    
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

class FatDecimalTextFieldTableViewCell: TextFieldTableViewCell {
    
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

