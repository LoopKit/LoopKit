//
//  ErrorBackgroundView.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/15/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit

public class ErrorBackgroundView: UIView {

    @IBOutlet var errorDescriptionLabel: UILabel!

    public func setErrorDescriptionLabel(with label: String?) {
        guard let label = label else {
            return
        }
        
        errorDescriptionLabel.text = label
    }
}
