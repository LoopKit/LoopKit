//
//  OverridePresetCollectionViewCell.swift
//  Loop
//
//  Created by Michael Pangburn on 1/2/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import UIKit


final class OverridePresetCollectionViewCell: UICollectionViewCell, IdentifiableClass {
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var startTimeLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!

    override var isSelected: Bool {
        didSet {
            updateSelectionState()
        }
    }

    override var isHighlighted: Bool {
        didSet {
            updateSelectionState()
        }
    }

    private func updateSelectionState() {
        if isSelected || isHighlighted {
            backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
        } else {
            backgroundColor = .white
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundColor = .white
        layer.cornerRadius = 16
    }
}
