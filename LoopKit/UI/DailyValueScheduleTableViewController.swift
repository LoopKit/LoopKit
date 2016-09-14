//
//  DailyValueScheduleTableViewController.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/6/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit


public protocol DailyValueScheduleTableViewControllerDelegate: class {
    func dailyValueScheduleTableViewControllerWillFinishUpdating(_ controller: DailyValueScheduleTableViewController)
}


func insertableIndices<T>(for scheduleItems: [RepeatingScheduleValue<T>], removing row: Int, with interval: TimeInterval) -> [Bool] {

    let insertableIndices = scheduleItems.enumerated().map { (index, item) -> Bool in
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


public class DailyValueScheduleTableViewController: UITableViewController {

    private var keyboardWillShowNotificationObserver: Any?

    public init() {
        super.init(style: .plain)
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItems = [insertButtonItem(), editButtonItem]

        let localTimeZone = TimeZone.current
        let timeZoneDiff = TimeInterval(timeZone.secondsFromGMT() - localTimeZone.secondsFromGMT())

        if timeZoneDiff != 0 {
            let localTimeZoneName = localTimeZone.abbreviation() ?? localTimeZone.identifier
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute]
            let diffString = formatter.string(from: abs(timeZoneDiff)) ?? String(abs(timeZoneDiff))

            navigationItem.prompt = String(
                format: NSLocalizedString("Times in %1$@%2$@%3$@", comment: "The schedule table view header describing the configured time zone difference from the default time zone. The substitution parameters are: (1: time zone name)(2: +/-)(3: time interval)"),
                localTimeZoneName, timeZoneDiff < 0 ? "-" : "+", diffString
            )
        }

        tableView.keyboardDismissMode = .onDrag

        keyboardWillShowNotificationObserver = NotificationCenter.default.addObserver(forName: .UIKeyboardWillShow, object: nil, queue: OperationQueue.main, using: { [unowned self] (note) -> Void in

            guard note.userInfo?[UIKeyboardIsLocalUserInfoKey] as? Bool == true else {
                return
            }

            let animated = note.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? Double ?? 0 > 0

            if let indexPath = self.tableView.indexPathForSelectedRow {
                self.tableView.beginUpdates()
                self.tableView.deselectRow(at: indexPath, animated: animated)
                self.tableView.endUpdates()
            }
        })
    }

    public override func setEditing(_ editing: Bool, animated: Bool) {
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

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        tableView.endEditing(true)

        delegate?.dailyValueScheduleTableViewControllerWillFinishUpdating(self)
    }

    public weak var delegate: DailyValueScheduleTableViewControllerDelegate?

    public func insertButtonItem() -> UIBarButtonItem {
        return UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addScheduleItem(_:)))
    }

    // MARK: - State

    public var timeZone = TimeZone.current {
        didSet {
            calendar.timeZone = timeZone
        }
    }

    public var unitDisplayString: String = "U/hour"

    private var calendar = Calendar.current

    var midnight: Date {
        return calendar.startOfDay(for: Date())
    }

    func addScheduleItem(_ sender: Any?) {
        // Updates the table view state. Subclasses should update their data model before calling super

        tableView.insertRows(at: [IndexPath(row: tableView.numberOfRows(inSection: 0), section: 0)], with: .automatic)
    }

    func insertableIndiciesByRemovingRow(_ row: Int, withInterval timeInterval: TimeInterval) -> [Bool] {
        fatalError("Subclasses must override __FUNCTION__")
    }

    // MARK: - UITableViewDataSource

    public override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        fatalError("Subclasses must override __FUNCTION__")
    }

    public override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    public override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return indexPath.row > 0
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        fatalError("Subclasses must override __FUNCTION__")
    }

    public override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Updates the table view state. Subclasses should update their data model before calling super

            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }

    // MARK: - UITableViewDelegate

    public override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return tableView.indexPathForSelectedRow == indexPath ? 196 : 44
    }

    public override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return indexPath.row > 0
    }

    public override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if indexPath == tableView.indexPathForSelectedRow {
            tableView.beginUpdates()
            tableView.deselectRow(at: indexPath, animated: false)
            tableView.endUpdates()

            return nil
        } else if indexPath.row == 0 {
            return nil
        }

        return indexPath
    }

    public override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        tableView.beginUpdates()
        tableView.endUpdates()
    }

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.endEditing(false)
        tableView.beginUpdates()
        tableView.endUpdates()
    }

    public override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {

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

    // MARK: - RepeatingScheduleValueTableViewCellDelegate

    func repeatingScheduleValueTableViewCellDidUpdateDate(_ cell: RepeatingScheduleValueTableViewCell) {

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
