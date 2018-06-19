//
//  SwitchTableViewCell.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 3/13/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit


public final class SwitchTableViewCell: UITableViewCell {

    @IBOutlet public weak var titleLabel: UILabel?

    @IBOutlet public weak var subtitleLabel: UILabel?

    public var `switch`: UISwitch?

    override public func awakeFromNib() {
        super.awakeFromNib()

        `switch` = UISwitch(frame: .zero)
        accessoryView = `switch`
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        contentView.layoutMargins.left = separatorInset.left
        contentView.layoutMargins.right = separatorInset.left
    }

    override public func prepareForReuse() {
        super.prepareForReuse()

        self.switch?.removeTarget(nil, action: nil, for: .valueChanged)
    }

}
