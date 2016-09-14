//
//  SingleValueScheduleTableViewController.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/13/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit

public class SingleValueScheduleTableViewController: DailyValueScheduleTableViewController, RepeatingScheduleValueTableViewCellDelegate {

    public override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(RepeatingScheduleValueTableViewCell.nib(), forCellReuseIdentifier: RepeatingScheduleValueTableViewCell.className)
    }

    // MARK: - State

    public var scheduleItems: [RepeatingScheduleValue<Double>] = []

    override func addScheduleItem(_ sender: Any?) {
        tableView.endEditing(false)

        var startTime = TimeInterval(0)
        var value = 0.0

        if scheduleItems.count > 0, let cell = tableView.cellForRow(at: IndexPath(row: scheduleItems.count - 1, section: 0)) as? RepeatingScheduleValueTableViewCell {
            let lastItem = scheduleItems.last!
            let interval = cell.datePickerInterval

            startTime = lastItem.startTime + interval
            value = lastItem.value

            if startTime >= TimeInterval(hours: 24) {
                return
            }
        }

        scheduleItems.append(
            RepeatingScheduleValue(
                startTime: min(TimeInterval(hours: 23.5), startTime),
                value: value
            )
        )

        super.addScheduleItem(sender)
    }

    override func insertableIndiciesByRemovingRow(_ row: Int, withInterval timeInterval: TimeInterval) -> [Bool] {
        return insertableIndices(for: scheduleItems, removing: row, with: timeInterval)
    }

    func preferredValueMinimumFractionDigits() -> Int {
        return 1
    }

    // MARK: - UITableViewDataSource

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return scheduleItems.count
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: RepeatingScheduleValueTableViewCell.className, for: indexPath) as! RepeatingScheduleValueTableViewCell

        let item = scheduleItems[indexPath.row]
        let interval = cell.datePickerInterval

        cell.timeZone = timeZone
        cell.date = midnight.addingTimeInterval(item.startTime)

        cell.valueNumberFormatter.minimumFractionDigits = preferredValueMinimumFractionDigits()

        cell.value = item.value
        cell.unitString = unitDisplayString
        cell.delegate = self

        if indexPath.row > 0 {
            let lastItem = scheduleItems[indexPath.row - 1]

            cell.datePicker.minimumDate = midnight.addingTimeInterval(lastItem.startTime).addingTimeInterval(interval)
        }

        if indexPath.row < scheduleItems.endIndex - 1 {
            let nextItem = scheduleItems[indexPath.row + 1]

            cell.datePicker.maximumDate = midnight.addingTimeInterval(nextItem.startTime).addingTimeInterval(-interval)
        } else {
            cell.datePicker.maximumDate = midnight.addingTimeInterval(TimeInterval(hours: 24) - interval)
            
        }
        
        return cell
    }

    public override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            scheduleItems.remove(at: indexPath.row)

            super.tableView(tableView, commit: editingStyle, forRowAt: indexPath)
        }
    }

    public override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {

        if sourceIndexPath != destinationIndexPath {
            let item = scheduleItems.remove(at: sourceIndexPath.row)
            scheduleItems.insert(item, at: destinationIndexPath.row)

            guard destinationIndexPath.row > 0, let cell = tableView.cellForRow(at: destinationIndexPath) as? RepeatingScheduleValueTableViewCell else {
                return
            }

            let interval = cell.datePickerInterval
            let startTime = scheduleItems[destinationIndexPath.row - 1].startTime + interval

            scheduleItems[destinationIndexPath.row] = RepeatingScheduleValue(startTime: startTime, value: scheduleItems[destinationIndexPath.row].value)

            // Since the valid date ranges of neighboring cells are affected, the lazy solution is to just reload the entire table view
            DispatchQueue.main.async {
                tableView.reloadData()
            }
        }
    }

    // MARK: - UITableViewDelegate

    public override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {

        guard sourceIndexPath != proposedDestinationIndexPath, let cell = tableView.cellForRow(at: sourceIndexPath) as? RepeatingScheduleValueTableViewCell else {
            return proposedDestinationIndexPath
        }

        let interval = cell.datePickerInterval
        let indices = insertableIndices(for: scheduleItems, removing: sourceIndexPath.row, with: interval)

        if indices[proposedDestinationIndexPath.row] {
            return proposedDestinationIndexPath
        } else {
            var closestRow = sourceIndexPath.row

            for (index, valid) in indices.enumerated() where valid {
                if abs(proposedDestinationIndexPath.row - index) < closestRow {
                    closestRow = index
                }
            }

            return IndexPath(row: closestRow, section: proposedDestinationIndexPath.section)
        }
    }

    // MARK: - RepeatingScheduleValueTableViewCellDelegate

    override func repeatingScheduleValueTableViewCellDidUpdateDate(_ cell: RepeatingScheduleValueTableViewCell) {
        if let indexPath = tableView.indexPath(for: cell) {
            let currentItem = scheduleItems[indexPath.row]

            scheduleItems[indexPath.row] = RepeatingScheduleValue(
                startTime: cell.date.timeIntervalSince(midnight),
                value: currentItem.value
            )
        }

        super.repeatingScheduleValueTableViewCellDidUpdateDate(cell)
    }

    func repeatingScheduleValueTableViewCellDidUpdateValue(_ cell: RepeatingScheduleValueTableViewCell) {
        if let indexPath = tableView.indexPath(for: cell) {
            let currentItem = scheduleItems[indexPath.row]

            scheduleItems[indexPath.row] = RepeatingScheduleValue(startTime: currentItem.startTime, value: cell.value)
        }
    }

}
