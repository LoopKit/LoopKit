//
//  HUDView.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 5/1/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit

public typealias HUDViewOrderPriority = Int

@objc open class BaseHUDView: UIView {

    @IBOutlet weak public var caption: UILabel! {
        didSet {
            caption?.text = "–"
            // TODO: Setting this color in code because the nib isn't being applied correctly. Review at a later date.
            caption?.textColor = .label
        }
    }
    
    public var stateColors: StateColorPalette? {
        didSet {
            stateColorsDidUpdate()
        }
    }
    
    open func stateColorsDidUpdate() {
    }
    
    open var orderPriority: HUDViewOrderPriority {
        return 10
    }
}
