//
//  SettingsTableViewCell.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit


public class SettingsTableViewCell: UITableViewCell {
    public static let EnabledString = LocalizedString("Enabled", comment: "The detail text describing an enabled setting")
    public static let TapToSetString = LocalizedString("Tap to set", comment: "The empty-state text for a configuration value")

    public override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)

        setup()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        setup()
    }

    private func setup() {
        textLabel?.adjustsFontForContentSizeCategory = true
        textLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        detailTextLabel?.adjustsFontForContentSizeCategory = true
        detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .body)
    }

    override public func prepareForReuse() {
        super.prepareForReuse()
        accessoryType = .none
        textLabel?.text = nil
        detailTextLabel?.text = nil
    }
}
