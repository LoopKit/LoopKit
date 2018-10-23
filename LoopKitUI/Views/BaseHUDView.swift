//
//  HUDView.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 5/1/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit

@objc open class BaseHUDView: UIView {

    @IBOutlet weak public var caption: UILabel! {
        didSet {
            caption?.text = "—"
        }
    }
    
    public var stateColors: StateColorPalette? {
        didSet {
            stateColorsDidUpdate()
        }
    }
    
    open func stateColorsDidUpdate() {
    }
}
