//
//  BatteryLevelHUDView.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 5/2/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit


public final class BatteryLevelHUDView: LevelHUDView, NibLoadable {

    override public var orderPriority: HUDViewOrderPriority {
        return 5
    }

    public class func instantiate() -> BatteryLevelHUDView {
        return nib().instantiate(withOwner: nil, options: nil)[0] as! BatteryLevelHUDView
    }

    private lazy var numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent

        return formatter
    }()

    public var batteryLevel: Double? {
        didSet {
            if let value = batteryLevel, let level = numberFormatter.string(from: value) {
                caption.text = level
                accessibilityValue = level
            } else {
                caption.text = nil
                accessibilityValue = nil
            }

            level = batteryLevel
        }
    }

}
