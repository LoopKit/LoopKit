//
//  SetupButton.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit

public class SetupButton: UIButton {

    public override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    public override func awakeFromNib() {
        super.awakeFromNib()

        setup()
    }

    private func setup() {
        backgroundColor = tintColor
        layer.cornerRadius = 6

        titleLabel?.adjustsFontForContentSizeCategory = true
        contentEdgeInsets.top = 14
        contentEdgeInsets.bottom = 14
        setTitleColor(.white, for: .normal)
    }

    public override func tintColorDidChange() {
        super.tintColorDidChange()

        backgroundColor = tintColor
    }

    public override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()

        tintColor = .blue
        tintColorDidChange()
    }

    public override var isHighlighted: Bool {
        didSet {
            alpha = isHighlighted ? 0.5 : 1
        }
    }

    public override var isEnabled: Bool {
        didSet {
            tintAdjustmentMode = isEnabled ? .automatic : .dimmed
        }
    }
}
