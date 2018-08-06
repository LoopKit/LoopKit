//
//  DailyValueScheduleTableViewController.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/6/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit
import LoopKit


public protocol DailyValueScheduleTableViewControllerDelegate: class {
    func dailyValueScheduleTableViewControllerWillFinishUpdating(_ controller: DailyValueScheduleTableViewController)
}


func insertableIndices<T>(for scheduleItems: [RepeatingScheduleValue<T>], removing row: Int, with interval: TimeInterval) -> [Bool] {

    let insertableIndices = scheduleItems.enumerated().map { (enumeration) -> Bool in
        let (index, item) = enumeration

        if row == index {
            return true
        } else if index == 0 {
            return false
        } else if index == scheduleItems.endIndex - 1 {
            return item.startTime < TimeInterval(hours: 24) - interval
        } else if index > row {
            return scheduleItems[index + 1].startTime - item.startTime > interval
        } else {
            return item.startTime - scheduleItems[index - 1].startTime > interval
        }
    }

    return insertableIndices
}


open class DailyValueScheduleTableViewController: UITableViewController, DatePickerTableViewCellDelegate {

    private var keyboardWillShowNotificationObserver: Any?

    public convenience init() {
        self.init(style: .plain)
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 44

        if !isReadOnly {
            navigationItem.rightBarButtonItems = [insertButtonItem(), editButtonItem]
        }

        tableView.keyboardDismissMode = .onDrag

        keyboardWillShowNotificationObserver = NotificationCenter.default.addObserver(forName: .UIKeyboardWillShow, object: nil, queue: OperationQueue.main, using: { [weak self] (note) -> Void in
            guard let strongSelf = self else {
                return
            }

            guard note.userInfo?[UIKeyboardIsLocalUserInfoKey] as? Bool == true else {
                return
            }

            let animated = note.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? Double ?? 0 > 0

            if let indexPath = strongSelf.tableView.indexPathForSelectedRow {
                strongSelf.tableView.beginUpdates()
                strongSelf.tableView.deselectRow(at: indexPath, animated: animated)
                strongSelf.tableView.endUpdates()
            }
        })
    }

    open override func setEditing(_ editing: Bool, animated: Bool) {
        if let indexPath = tableView.indexPathForSelectedRow {
            tableView.beginUpdates()
            tableView.deselectRow(at: indexPath, animated: animated)
            tableView.endUpdates()
        }

        tableView.endEditing(false)

        navigationItem.rightBarButtonItems?[0].isEnabled = !editing

        super.setEditing(editing, animated: animated)
    }

    deinit {
        if let observer = keyboardWillShowNotificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        tableView.endEditing(true)
    }

    public weak var delegate: DailyValueScheduleTableViewControllerDelegate?

    public func insertButtonItem() -> UIBarButtonItem {
        return UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addScheduleItem(_:)))
    }

    // MARK: - State

    public var timeZone = TimeZone.currentFixed {
        didSet {
            calendar.timeZone = timeZone

            let localTimeZone = TimeZone.current
            let timeZoneDiff = TimeInterval(timeZone.secondsFromGMT() - localTimeZone.secondsFromGMT())

            if timeZoneDiff != 0 {
                let localTimeZoneName = localTimeZone.abbreviation() ?? localTimeZone.identifier
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.hour, .minute]
                let diffString = formatter.string(from: abs(timeZoneDiff)) ?? String(abs(timeZoneDiff))

                navigationItem.prompt = String(
                    format: LocalizedString("Times in %1$@%2$@%3$@", comment: "The schedule table view header describing the configured time zone difference from the default time zone. The substitution parameters are: (1: time zone name)(2: +/-)(3: time interval)"),
                    localTimeZoneName, timeZoneDiff < 0 ? "-" : "+", diffString
                )
            }
        }
    }

    public var unitDisplayString: String = "U/hour"

    public var isReadOnly: Bool = false {
        didSet {
            if isReadOnly {
                isEditing = false
            }

            if isViewLoaded {
                navigationItem.setRightBarButtonItems(isReadOnly ? [] : [insertButtonItem(), editButtonItem], animated: true)
            }
        }
    }

    private var calendar = Calendar.current

    var midnight: Date {
        return calendar.startOfDay(for: Date())
    }

    @objc func addScheduleItem(_ sender: Any?) {
        guard !isReadOnly else {
            return
        }
        // Updates the table view state. Subclasses should update their data model before calling super

        tableView.insertRows(at: [IndexPath(row: tableView.numberOfRows(inSection: 0), section: 0)], with: .automatic)
    }

    func insertableIndiciesByRemovingRow(_ row: Int, withInterval timeInterval: TimeInterval) -> [Bool] {
        fatalError("Subclasses must override \(#function)")
    }

    // MARK: - UITableViewDataSource

    open override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    open override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        fatalError("Subclasses must override \(#function)")
    }

    open override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return !isReadOnly && indexPath.section == 0 && indexPath.row > 0
    }

    open override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return self.tableView(tableView, canEditRowAt: indexPath)
    }

    open override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        fatalError("Subclasses must override \(#function)")
    }

    open override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Updates the table view state. Subclasses should update their data model before calling super

            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }

    // MARK: - UITableViewDelegate

    open override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        guard indexPath.section == 0 else {
            return true
        }

        return !isReadOnly && indexPath.row > 0
    }

    open override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard self.tableView(tableView, shouldHighlightRowAt: indexPath) else {
            return nil
        }

        tableView.endEditing(false)
        tableView.beginUpdates()
        hideDatePickerCells(excluding: indexPath)
        return indexPath
    }

    open override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        tableView.beginUpdates()
        tableView.endUpdates()
    }

    open override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.endEditing(false)
        tableView.endUpdates()
        tableView.deselectRow(at: indexPath, animated: true)
    }

    open override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {

        guard sourceIndexPath.section == proposedDestinationIndexPath.section else {
            return sourceIndexPath
        }

        guard sourceIndexPath != proposedDestinationIndexPath, let cell = tableView.cellForRow(at: sourceIndexPath) as? RepeatingScheduleValueTableViewCell else {
            return proposedDestinationIndexPath
        }

        let interval = cell.datePickerInterval
        let insertableIndices = insertableIndiciesByRemovingRow(sourceIndexPath.row, withInterval: interval)

        if insertableIndices[proposedDestinationIndexPath.row] {
            return proposedDestinationIndexPath
        } else {
            var closestRow = sourceIndexPath.row

            for (index, valid) in insertableIndices.enumerated() where valid {
                if abs(proposedDestinationIndexPath.row - index) < closestRow {
                    closestRow = index
                }
            }

            return IndexPath(row: closestRow, section: proposedDestinationIndexPath.section)
        }
    }

    // MARK: - DatePickerTableViewCellDelegate

    func datePickerTableViewCellDidUpdateDate(_ cell: DatePickerTableViewCell) {

        // Updates the TableView state. Subclasses should update their data model
        if let indexPath = tableView.indexPath(for: cell) {

            var indexPaths: [IndexPath] = []

            if indexPath.row > 0 {
                indexPaths.append(IndexPath(row: indexPath.row - 1, section: indexPath.section))
            }

            if indexPath.row < tableView.numberOfRows(inSection: 0) - 1 {
                indexPaths.append(IndexPath(row: indexPath.row + 1, section: indexPath.section))
            }

            DispatchQueue.main.async {
                self.tableView.reloadRows(at: indexPaths, with: .none)
            }
        }
    }

}
