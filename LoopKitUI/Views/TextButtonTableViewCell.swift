//
//  TextButtonTableViewCell.swift
//  LoopKitUI
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit

public class TextButtonTableViewCell: UITableViewCell {

    override public init(style: UITableViewCellStyle, reuseIdentifier: String?) {
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

    public var isLoading = false {
        didSet {
            if isLoading {
                let indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
                accessoryView = indicator
                indicator.startAnimating()
            } else {
                accessoryView = nil
            }
        }
    }

    public override func tintColorDidChange() {
        super.tintColorDidChange()

        textLabel?.textColor = tintColor
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        textLabel?.textColor = tintColor
    }
}
