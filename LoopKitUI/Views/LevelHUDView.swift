//
//  LevelHUDView.swift
//  Loop
//
//  Created by Nate Racklyeft on 2/4/17.
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import UIKit

open class LevelHUDView: BaseHUDView {

    @IBOutlet private weak var levelMaskView: LevelMaskView!

    override open func awakeFromNib() {
        super.awakeFromNib()

        updateColor()

        accessibilityValue = LocalizedString("Unknown", comment: "Accessibility value for an unknown value")
    }

    override open func stateColorsDidUpdate() {
        super.stateColorsDidUpdate()
        updateColor()
    }
        
    private func updateColor() {
        levelMaskView.tintColor = nil

        switch level {
        case .none:
            tintColor = stateColors?.unknown
        case let x? where x > 0.25:
            tintColor = stateColors?.normal
        case let x? where x > 0.10:
            tintColor = stateColors?.warning
            levelMaskView.tintColor = stateColors?.warning
        default:
            tintColor = stateColors?.error
        }
    }

    public var level: Double? {
        didSet {
            levelMaskView.value = level ?? 1.0
            levelDidChange()
        }
    }

    open func levelDidChange() {
        updateColor()
    }
}
