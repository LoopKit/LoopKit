//
//  GlucoseRangeScheduleTableViewController.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/13/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit
import HealthKit


public class GlucoseRangeScheduleTableViewController: DailyValueScheduleTableViewController, RepeatingScheduleValueTableViewCellDelegate {

    public var unit: HKUnit = HKUnit.milligramsPerDeciliterUnit() {
        didSet {
            unitDisplayString = unit.glucoseUnitDisplayString
        }
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        tableView.registerNib(GlucoseRangeTableViewCell.nib(), forCellReuseIdentifier: GlucoseRangeTableViewCell.className)
        tableView.registerNib(GlucoseRangeOverrideTableViewCell.nib(), forCellReuseIdentifier: GlucoseRangeOverrideTableViewCell.className)
    }

    // MARK: - State

    public var scheduleItems: [RepeatingScheduleValue<DoubleRange>] = []

    override func addScheduleItem(sender: AnyObject?) {
        var startTime = NSTimeInterval(0)
        let value: DoubleRange

        if scheduleItems.count > 0, let cell = tableView.cellForRowAtIndexPath(NSIndexPath(forRow: scheduleItems.count - 1, inSection: Section.schedule.rawValue)) as? GlucoseRangeTableViewCell {
            let lastItem = scheduleItems.last!
            let interval = cell.datePickerInterval

            startTime = lastItem.startTime + interval
            value = lastItem.value

            if startTime >= NSTimeInterval(hours: 24) {
                return
            }
        } else {
            value = DoubleRange(minValue: 0, maxValue: 0)
        }

        scheduleItems.append(
            RepeatingScheduleValue(
                startTime: min(NSTimeInterval(hours: 23.5), startTime),
                value: value
            )
        )

        tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: scheduleItems.count - 1, inSection: Section.schedule.rawValue)], withRowAnimation: .Automatic)
    }

    override func insertableIndiciesByRemovingRow(row: Int, withInterval timeInterval: NSTimeInterval) -> [Bool] {
        return insertableIndicesForScheduleItems(scheduleItems, byRemovingRow: row, withInterval: timeInterval)
    }

    // MARK: - UITableViewDataSource

    private enum Section: Int {
        case schedule = 0
        case override

        static let count = 2
    }

    public override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return Section.count
    }

    public override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .schedule:
            return scheduleItems.count
        case .override:
            return 1
        }
    }

    public override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .schedule:
            let cell = tableView.dequeueReusableCellWithIdentifier(GlucoseRangeTableViewCell.className, forIndexPath: indexPath) as! GlucoseRangeTableViewCell

            let item = scheduleItems[indexPath.row]
            let interval = cell.datePickerInterval

            cell.timeZone = timeZone
            cell.date = midnight.dateByAddingTimeInterval(item.startTime)

            cell.valueNumberFormatter.minimumFractionDigits = unit.preferredMinimumFractionDigits

            cell.minValue = item.value.minValue
            cell.value = item.value.maxValue
            cell.unitString = unitDisplayString
            cell.delegate = self

            if indexPath.row > 0 {
                let lastItem = scheduleItems[indexPath.row - 1]

                cell.datePicker.minimumDate = midnight.dateByAddingTimeInterval(lastItem.startTime).dateByAddingTimeInterval(interval)
            }

            if indexPath.row < scheduleItems.endIndex - 1 {
                let nextItem = scheduleItems[indexPath.row + 1]

                cell.datePicker.maximumDate = midnight.dateByAddingTimeInterval(nextItem.startTime).dateByAddingTimeInterval(-interval)
            } else {
                cell.datePicker.maximumDate = midnight.dateByAddingTimeInterval(NSTimeInterval(hours: 24) - interval)
            }

            return cell
        case .override:
            let cell = tableView.dequeueReusableCellWithIdentifier(GlucoseRangeOverrideTableViewCell.className, forIndexPath: indexPath) as! GlucoseRangeOverrideTableViewCell

            cell.valueNumberFormatter.minimumFractionDigits = unit.preferredMinimumFractionDigits

// TODO: Populate with the data model
//            cell.minValue = 
//            cell.maxValue = 
            cell.unitString = unitDisplayString
            cell.delegate = self

            cell.iconImageView.tintColor = tableView.tintColor

            return cell
        }
    }

    public override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            scheduleItems.removeAtIndex(indexPath.row)

            super.tableView(tableView, commitEditingStyle: editingStyle, forRowAtIndexPath: indexPath)
        }
    }

    public override func tableView(tableView: UITableView, moveRowAtIndexPath sourceIndexPath: NSIndexPath, toIndexPath destinationIndexPath: NSIndexPath) {
        if sourceIndexPath != destinationIndexPath {
            switch Section(rawValue: destinationIndexPath.section)! {
            case .schedule:
                let item = scheduleItems.removeAtIndex(sourceIndexPath.row)
                scheduleItems.insert(item, atIndex: destinationIndexPath.row)

                guard destinationIndexPath.row > 0, let cell = tableView.cellForRowAtIndexPath(destinationIndexPath) as? GlucoseRangeTableViewCell else {
                    return
                }

                let interval = cell.datePickerInterval
                let startTime = scheduleItems[destinationIndexPath.row - 1].startTime + interval

                scheduleItems[destinationIndexPath.row] = RepeatingScheduleValue(startTime: startTime, value: scheduleItems[destinationIndexPath.row].value)

                // Since the valid date ranges of neighboring cells are affected, the lazy solution is to just reload the entire table view
                dispatch_async(dispatch_get_main_queue()) {
                    tableView.reloadData()
                }
            case .override:
                break
            }
        }
    }

    public override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        switch Section(rawValue: indexPath.section)! {
        case .schedule:
            return true
        case .override:
            return false
        }
    }

    public override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        switch Section(rawValue: indexPath.section)! {
        case .schedule:
            return true
        case .override:
            return false
        }
    }

    public override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .schedule:
            return nil
        case .override:
            return NSLocalizedString("Overrides", comment: "The section title of glucose overrides")
        }
    }

    // MARK: - RepeatingScheduleValueTableViewCellDelegate

    override func repeatingScheduleValueTableViewCellDidUpdateDate(cell: RepeatingScheduleValueTableViewCell) {
        if let indexPath = tableView.indexPathForCell(cell) {
            let currentItem = scheduleItems[indexPath.row]

            scheduleItems[indexPath.row] = RepeatingScheduleValue(
                startTime: cell.date.timeIntervalSinceDate(midnight),
                value: currentItem.value
            )
        }

        super.repeatingScheduleValueTableViewCellDidUpdateDate(cell)
    }

    func repeatingScheduleValueTableViewCellDidUpdateValue(cell: RepeatingScheduleValueTableViewCell) {
        if let indexPath = tableView.indexPathForCell(cell), cell = cell as? GlucoseRangeTableViewCell {
            let currentItem = scheduleItems[indexPath.row]

            scheduleItems[indexPath.row] = RepeatingScheduleValue(startTime: currentItem.startTime, value: DoubleRange(minValue: cell.minValue, maxValue: cell.value))
        }
    }

}


extension GlucoseRangeScheduleTableViewController: GlucoseRangeOverrideTableViewCellDelegate {
    func glucoseRangeOverrideTableViewCellDidUpdateValue(cell: GlucoseRangeOverrideTableViewCell) {
//        let overrideRange = DoubleRange(minValue: cell.minValue, maxValue: cell.maxValue)
        // TODO: Update the model
    }
}
