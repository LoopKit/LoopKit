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
}


public class TextFieldTableViewCell: UITableViewCell, UITextFieldDelegate {

    @IBOutlet public weak var unitLabel: UILabel?

    @IBOutlet public weak var textField: UITextField! {
        didSet {
            textField.delegate = self
        }
    }

    override public func prepareForReuse() {
        super.prepareForReuse()

        textField.delegate = nil
        unitLabel?.text = nil
    }
    
    public weak var delegate: TextFieldTableViewCellDelegate?
    
    // MARK: - UITextFieldDelegate
    
    public func textFieldDidBeginEditing(_ textField: UITextField) {
        delegate?.textFieldTableViewCellDidBeginEditing(self)
    }
    
    public func textFieldDidEndEditing(_ textField: UITextField) {
        delegate?.textFieldTableViewCellDidEndEditing(self)
    }
}
