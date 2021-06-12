//
//  TextFieldTableViewCell.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 5/22/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit


public protocol TextFieldTableViewCellDelegate: class {
    func textFieldTableViewCellDidBeginEditing(_ cell: TextFieldTableViewCell)
    
    func textFieldTableViewCellDidEndEditing(_ cell: TextFieldTableViewCell)

    func textFieldTableViewCellDidChangeEditing(_ cell: TextFieldTableViewCell)
}

// MARK: - Default Implementations

extension TextFieldTableViewCellDelegate {
    public func textFieldTableViewCellDidChangeEditing(_ cell: TextFieldTableViewCell) { }
}


public class TextFieldTableViewCell: UITableViewCell, UITextFieldDelegate {

    @IBOutlet public weak var unitLabel: UILabel? {
        didSet {
            // Setting this color in code because the nib isn't being applied correctly
            unitLabel?.textColor = .secondaryLabel
        }
    }

    @IBOutlet public weak var textField: UITextField! {
        didSet {
            textField.delegate = self
            textField.addTarget(self, action: #selector(textFieldEditingChanged), for: .editingChanged)

            // Setting this color in code because the nib isn't being applied correctly
            textField.textColor = .label
        }
    }

    public var maximumTextLength: Int?

    override public func prepareForReuse() {
        super.prepareForReuse()

        textField.delegate = nil
        unitLabel?.text = nil
    }
    
    public weak var delegate: TextFieldTableViewCellDelegate?

    @objc private func textFieldEditingChanged() {
        delegate?.textFieldTableViewCellDidChangeEditing(self)
    }
    
    // MARK: - UITextFieldDelegate
    
    public func textFieldDidBeginEditing(_ textField: UITextField) {
        // Even though we are likely already on .main, we still need to queue this cursor (selection) change in
        // order for it to work
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.textField.moveCursorToEnd()
            self.delegate?.textFieldTableViewCellDidBeginEditing(self)
        }
    }
    
    public func textFieldDidEndEditing(_ textField: UITextField) {
        delegate?.textFieldTableViewCellDidEndEditing(self)
    }

    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let maximumTextLength = maximumTextLength else {
            return true
        }
        let text = textField.text ?? ""
        let allText = (text as NSString).replacingCharacters(in: range, with: string)
        if allText.count <= maximumTextLength {
            return true
        } else {
            textField.text = String(allText.prefix(maximumTextLength))
            return false
        }
    }
}
