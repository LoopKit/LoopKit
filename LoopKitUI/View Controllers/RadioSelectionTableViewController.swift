//
//  RadioSelectionTableViewController.swift
//  Loop
//
//  Created by Nate Racklyeft on 8/26/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit

public protocol RadioSelectionTableViewControllerDelegate: class {
    func radioSelectionTableViewControllerDidChangeSelectedIndex(_ controller: RadioSelectionTableViewController)
}


open class RadioSelectionTableViewController: UITableViewController {

    open var options = [String]()

    open var selectedIndex: Int? {
        didSet {
            if let oldValue = oldValue, oldValue != selectedIndex {
                tableView.cellForRow(at: IndexPath(row: oldValue, section: 0))?.accessoryType = .none
            }

            if let selectedIndex = selectedIndex, oldValue != selectedIndex {
                tableView.cellForRow(at: IndexPath(row: selectedIndex, section: 0))?.accessoryType = .checkmark

                delegate?.radioSelectionTableViewControllerDidChangeSelectedIndex(self)
            }
        }
    }

    open var contextHelp: String?

    weak open var delegate: RadioSelectionTableViewControllerDelegate?

    convenience public init() {
        self.init(style: .grouped)
    }

    // MARK: - Table view data source

    override open func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return options.count
    }

    override open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") ?? UITableViewCell(style: .default, reuseIdentifier: "Cell")

        cell.textLabel?.text = options[indexPath.row]
        cell.accessoryType = selectedIndex == indexPath.row ? .checkmark : .none

        return cell
    }

    override open func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return contextHelp
    }

    override open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedIndex = indexPath.row

        tableView.deselectRow(at: indexPath, animated: true)
    }
}
