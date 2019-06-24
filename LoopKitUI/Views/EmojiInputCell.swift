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
        backgroundColor = isSelected || isHighlighted ? .white : nil
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        layer.cornerRadius = 8
    }
}
