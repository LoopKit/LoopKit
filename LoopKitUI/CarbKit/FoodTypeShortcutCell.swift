//
//  FoodTypeShortcutCell.swift
//  LoopKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import UIKit

protocol FoodTypeShortcutCellDelegate: class {
    func foodTypeShortcutCellDidUpdateSelection(_ cell: FoodTypeShortcutCell)
}


class FoodTypeShortcutCell: UITableViewCell {

    @IBOutlet var buttonStack: UIStackView!

    enum SelectionState: Int {
        case fast
        case medium
        case slow
        case custom
    }

    var selectionState = SelectionState.medium {
        didSet {
            updateButtons()
        }
    }

    weak var delegate: FoodTypeShortcutCellDelegate?

    override func layoutSubviews() {
        super.layoutSubviews()

        contentView.layoutMargins.left = separatorInset.left
        contentView.layoutMargins.right = separatorInset.left
    }

    func updateButtons() {
        for case (let index, let button as UIButton) in buttonStack.arrangedSubviews.enumerated() {
            button.isSelected = (index == selectionState.rawValue)
        }
    }

    @IBAction func buttonTapped(_ sender: UIButton) {
        guard let index = buttonStack.arrangedSubviews.firstIndex(of: sender),
            let selection = SelectionState(rawValue: index)
        else {
            return
        }

        selectionState = selection
        delegate?.foodTypeShortcutCellDidUpdateSelection(self)
    }
}
