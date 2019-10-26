//
//  EmojiInputCell.swift
//  LoopKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import UIKit

class EmojiInputCell: UICollectionViewCell, IdentifiableClass {
    @IBOutlet var label: UILabel!

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
        let highlightColor: UIColor

        if #available(iOSApplicationExtension 13.0, *) {
            highlightColor = .tertiarySystemFill
        } else {
            highlightColor = .white
        }

        backgroundColor = isSelected || isHighlighted ? highlightColor : nil
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        layer.cornerRadius = 8
    }
}
