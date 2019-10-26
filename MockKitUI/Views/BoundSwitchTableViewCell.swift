//
//  BoundSwitchTableViewCell.swift
//  MockKitUI
//
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKitUI

class BoundSwitchTableViewCell: SwitchTableViewCell {

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    var onToggle: ((_ isOn: Bool) -> Void)? {
        didSet {
            if onToggle == nil {
                self.switch?.removeTarget(nil, action: nil, for: .valueChanged)
            } else {
                `switch`?.addTarget(self, action: #selector(respondToToggle), for: .valueChanged)
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        onToggle = nil
        `switch`?.addTarget(self, action: #selector(respondToToggle), for: .valueChanged)
    }

    @objc private func respondToToggle() {
        if let `switch` = `switch`, let onToggle = onToggle {
            onToggle(`switch`.isOn)
        }
    }
}
