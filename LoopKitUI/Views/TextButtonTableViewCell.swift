//
//  TextButtonTableViewCell.swift
//  LoopKitUI
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit

open class TextButtonTableViewCell: LoadingTableViewCell {

    override public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)

        textLabel?.tintAdjustmentMode = .automatic
        textLabel?.textColor = tintColor
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    public var isEnabled = true {
        didSet {
            tintAdjustmentMode = isEnabled ? .normal : .dimmed
            selectionStyle = isEnabled ? .default : .none
        }
    }

    open override func tintColorDidChange() {
        super.tintColorDidChange()

        textLabel?.textColor = tintColor
    }

    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        textLabel?.textColor = tintColor
    }

    open override func prepareForReuse() {
        super.prepareForReuse()

        textLabel?.textAlignment = .natural
        tintColor = nil
        isEnabled = true
    }
}
