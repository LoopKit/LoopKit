//
//  HUDView.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 5/1/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit

public typealias HUDViewIdentifier = Int

@objc open class BaseHUDView: UIView {

    @IBOutlet weak public var caption: UILabel! {
        didSet {
            caption?.text = "—"
        }
    }
    
    public let hudViewIdentifier = 0
}
