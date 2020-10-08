//
//  ReservoirVolumeHUDView.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 5/2/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit

public final class ReservoirVolumeHUDView: LevelHUDView, NibLoadable {
    
    override public var orderPriority: HUDViewOrderPriority {
        return 4
    }

    @IBOutlet private weak var volumeLabel: UILabel!
    
    public class func instantiate() -> ReservoirVolumeHUDView {
        return nib().instantiate(withOwner: nil, options: nil)[0] as! ReservoirVolumeHUDView
    }

    override public func awakeFromNib() {
        super.awakeFromNib()

        volumeLabel.isHidden = true
    }

    override public func levelDidChange() {
        super.levelDidChange()

        switch level {
        case .none:
            volumeLabel.isHidden = true
        case let x? where x > 0.25:
            volumeLabel.isHidden = true
        case let x? where x > 0.10:
            volumeLabel.textColor = tintColor
            volumeLabel.isHidden = false
        default:
            volumeLabel.textColor = tintColor
            volumeLabel.isHidden = false
        }
    }

    private lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        return formatter
    }()

    private lazy var numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        return formatter
    }()

    public func setReservoirVolume(volume: Double, at date: Date) {
        if let units = numberFormatter.string(from: volume) {
            volumeLabel.text = String(format: LocalizedString("%@U", comment: "Format string for reservoir volume. (1: The localized volume)"), units)
            let time = timeFormatter.string(from: date)
            caption?.text = time

            accessibilityValue = String(format: LocalizedString("%1$@ units remaining at %2$@", comment: "Accessibility format string for (1: localized volume)(2: time)"), units, time)
        }
    }

    public override func tintColorDidChange() {
        super.tintColorDidChange()

        volumeLabel.textColor = tintColor
    }
}
