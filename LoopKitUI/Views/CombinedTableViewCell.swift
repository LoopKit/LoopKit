//
//  CombinedTableViewCell.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 2/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import UIKit


/// A generic adapter for stacking two UITableViewCells in a single cell.
/// Enables reuse of existing cell logic when creating more complex cells.
final class CombinedTableViewCell<TopCell: UITableViewCell, BottomCell: UITableViewCell>: UITableViewCell {
    private final class DataSource: NSObject, UITableViewDataSource {
        var topCell: TopCell?
        var bottomCell: BottomCell?

        private var cells: [UITableViewCell] {
            return [topCell, bottomCell].compactMap { $0 }
        }

        func numberOfSections(in tableView: UITableView) -> Int {
            return 1
        }

        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return cells.count
        }

        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            return cells[indexPath.row]
        }
    }

    private let dataSource = DataSource()

    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.separatorStyle = .none
        tableView.dataSource = dataSource
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.isScrollEnabled = false
        return tableView
    }()

    private lazy var tableViewHeightConstraint = tableView.heightAnchor.constraint(equalToConstant: fullTableViewHeight)

    var cells: (top: TopCell?, bottom: BottomCell?) {
        return (top: dataSource.topCell, bottom: dataSource.bottomCell)
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    private func setup() {
        contentView.addSubview(tableView)

        let leftConstraint = tableView.leftAnchor.constraint(equalTo: contentView.leftAnchor)
        leftConstraint.priority = .defaultHigh // Ensures constraint compliance when width == 0 in transition
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: contentView.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            leftConstraint,
            tableView.rightAnchor.constraint(equalTo: contentView.rightAnchor)
        ])

        tableViewHeightConstraint.isActive = true
    }

    func setCells(top: TopCell, bottom: BottomCell) {
        dataSource.topCell = top
        dataSource.bottomCell = bottom

        // Self-sizing cell height is computed on-demand.
        // Give the table enough space to show both cells, then constrain it to its full height.
        tableView.frame.size.height += top.frame.height + bottom.frame.height
        tableView.reloadData()
        tableViewHeightConstraint.constant = fullTableViewHeight
    }

    private var fullTableViewHeight: CGFloat {
        return tableView.visibleCells
            .map { $0.frame.height }
            .reduce(0, +)
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        dataSource.topCell = nil
        dataSource.bottomCell = nil
    }
}
