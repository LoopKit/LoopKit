//
//  TextFieldTableViewCell.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 5/22/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit

class TextFieldTableViewCell: UITableViewCell {

    @IBOutlet var unitLabel: UILabel!

    @IBOutlet var textField: UITextField!

    override func prepareForReuse() {
        super.prepareForReuse()

        textField.delegate = nil
        unitLabel.text = nil
    }
}
