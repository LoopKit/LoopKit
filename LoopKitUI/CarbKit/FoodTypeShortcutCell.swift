//
//  FoodTypeShortcutCell.swift
//  LoopKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import UIKit

public protocol FoodTypeShortcutCellDelegate: class {
    func foodTypeShortcutCellDidUpdateSelection(_ cell: FoodTypeShortcutCell)
}


public class FoodTypeShortcutCell: UITableViewCell {

    @IBOutlet var buttonStack: UIStackView!

    public enum SelectionState: Int {
        case fast
        case medium
        case slow
        case custom
    }

    public var selectionState = SelectionState.medium {
        didSet {
            updateButtons()
        }
    }

    public weak var delegate: FoodTypeShortcutCellDelegate?

    public var selectedEmoji: String {
        let selectedButton = buttonStack.arrangedSubviews[selectionState.rawValue] as! UIButton
        return selectedButton.title(for: .normal)!
    }

    public override func layoutSubviews() {
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
