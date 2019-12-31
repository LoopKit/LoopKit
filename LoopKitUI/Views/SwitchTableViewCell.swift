//
//  SwitchTableViewCell.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 3/13/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit


open class SwitchTableViewCell: UITableViewCell {

    public var `switch`: UISwitch?

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: Self.className)

        setUp()
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)

        setUp()
    }

    private func setUp() {
        `switch` = UISwitch(frame: .zero)
        accessoryView = `switch`
    }

    override open func layoutSubviews() {
        super.layoutSubviews()

        contentView.layoutMargins.left = separatorInset.left
        contentView.layoutMargins.right = separatorInset.left
    }

    override open func prepareForReuse() {
        super.prepareForReuse()

        self.switch?.removeTarget(nil, action: nil, for: .valueChanged)
    }
}
