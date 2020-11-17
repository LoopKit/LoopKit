//
//  SegmentedControlTableViewCell.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 7/14/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import UIKit


open class SegmentedControlTableViewCell: UITableViewCell {
    public var segmentedControl = UISegmentedControl(frame: .zero)

    public var options: [String] = [] {
        didSet {
            segmentedControl.removeAllSegments()
            for (index, option) in options.enumerated() {
                segmentedControl.insertSegment(withTitle: option, at: index, animated: false)
            }
        }
    }

    private var select: (_ index: Int) -> Void = { _ in }

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: Self.className)

        setUp()
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)

        setUp()
    }

    private func setUp() {
        contentView.addSubview(segmentedControl)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            segmentedControl.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            segmentedControl.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            segmentedControl.leadingAnchor.constraint(equalTo: textLabel?.trailingAnchor ?? contentView.leadingAnchor)
        ])
    }

    override open func layoutSubviews() {
        super.layoutSubviews()

        contentView.layoutMargins.left = separatorInset.left
        contentView.layoutMargins.right = separatorInset.left
    }

    override open func prepareForReuse() {
        super.prepareForReuse()

        segmentedControl.removeTarget(nil, action: nil, for: .valueChanged)
        select = { _ in }
    }

    public func onSelection(_ select: @escaping (_ index: Int) -> Void) {
        self.select = select
        segmentedControl.addTarget(self, action: #selector(handleSelection), for: .valueChanged)
    }

    @objc private func handleSelection() {
        select(segmentedControl.selectedSegmentIndex)
    }
}

