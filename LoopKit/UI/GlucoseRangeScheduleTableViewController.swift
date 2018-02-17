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

    public var unit: HKUnit = HKUnit.milligramsPerDeciliter() {
        didSet {
            unitDisplayString = unit.glucoseUnitDisplayString
        }
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(GlucoseRangeTableViewCell.nib(), forCellReuseIdentifier: GlucoseRangeTableViewCell.className)
        tableView.register(GlucoseRangeOverrideTableViewCell.nib(), forCellReuseIdentifier: GlucoseRangeOverrideTableViewCell.className)
    }

    // MARK: - State

    public var scheduleItems: [RepeatingScheduleValue<DoubleRange>] = []

    @available(*, deprecated, message: "Use `overrideRanges` instead")
    public var workoutRange: DoubleRange? {
        get {
            return overrideRanges[.workout]
        }
        set {
            overrideRanges[.workout] = newValue
        }
    }

    public let overrideContexts: [GlucoseRangeSchedule.Override.Context] = [.preMeal, .workout, .remoteTempTarget]

    public var overrideRanges: [GlucoseRangeSchedule.Override.Context: DoubleRange] = [:]

    override func addScheduleItem(_ sender: Any?) {
        var startTime = TimeInterval(0)
        let value: DoubleRange

        if scheduleItems.count > 0, let cell = tableView.cellForRow(at: IndexPath(row: scheduleItems.count - 1, section: Section.schedule.rawValue)) as? GlucoseRangeTableViewCell {
            let lastItem = scheduleItems.last!
            let interval = cell.datePickerInterval

            startTime = lastItem.startTime + interval
            value = lastItem.value

            if startTime >= TimeInterval(hours: 24) {
                return
            }
        } else {
            value = DoubleRange(minValue: 0, maxValue: 0)
        }

        scheduleItems.append(
            RepeatingScheduleValue(
                startTime: min(TimeInterval(hours: 23.5), startTime),
                value: value
            )
        )

        tableView.beginUpdates()

        tableView.insertRows(at: [IndexPath(row: scheduleItems.count - 1, section: Section.schedule.rawValue)], with: .automatic)

        if scheduleItems.count == 1 {
            tableView.insertSections(IndexSet(integer: Section.override.rawValue), with: .automatic)
        }

        tableView.endUpdates()
    }

    override func insertableIndiciesByRemovingRow(_ row: Int, withInterval timeInterval: TimeInterval) -> [Bool] {
        return insertableIndices(for: scheduleItems, removing: row, with: timeInterval)
    }

    // MARK: - UITableViewDataSource

    private enum Section: Int {
        case schedule = 0
        case override

        static let count = 2
    }

    public override func numberOfSections(in tableView: UITableView) -> Int {
        if scheduleItems.count == 0 {
            return Section.count - 1
        } else {
            return Section.count
        }
    }

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .schedule:
            return scheduleItems.count
        case .override:
            return overrideContexts.count
        }
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .schedule:
            let cell = tableView.dequeueReusableCell(withIdentifier: GlucoseRangeTableViewCell.className, for: indexPath) as! GlucoseRangeTableViewCell

            let item = scheduleItems[indexPath.row]
            let interval = cell.datePickerInterval

            cell.timeZone = timeZone
            cell.date = midnight.addingTimeInterval(item.startTime)

            cell.valueNumberFormatter.minimumFractionDigits = unit.preferredFractionDigits
            cell.valueNumberFormatter.maximumFractionDigits = unit.preferredFractionDigits

            cell.minValue = item.value.minValue
            cell.value = item.value.maxValue
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
        case .override:
            let cell = tableView.dequeueReusableCell(withIdentifier: GlucoseRangeOverrideTableViewCell.className, for: indexPath) as! GlucoseRangeOverrideTableViewCell

            cell.valueNumberFormatter.minimumFractionDigits = unit.preferredFractionDigits
            cell.valueNumberFormatter.maximumFractionDigits = unit.preferredFractionDigits

            let context = overrideContexts[indexPath.row]

            if let range = overrideRanges[context], !range.isZero {
                cell.minValue = range.minValue
                cell.maxValue = range.maxValue
            }

            cell.titleLabel.text = context.title

            let bundle = Bundle(for: type(of: self))
            let image: UIImage?

            switch context {
            case .workout:
                image = UIImage(named: "workout", in: bundle, compatibleWith: traitCollection)
            case .preMeal:
                image = UIImage(named: "Pre-Meal", in: bundle, compatibleWith: traitCollection)
            case .remoteTempTarget:
                image = UIImage(named: "ns-temp-blue", in: bundle, compatibleWith: traitCollection)
            }

            cell.iconImageView.image = image

            cell.unitString = unitDisplayString
            cell.delegate = self

            return cell
        }
    }

    public override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            scheduleItems.remove(at: indexPath.row)

            tableView.beginUpdates()

            tableView.deleteRows(at: [indexPath], with: .automatic)

            if scheduleItems.count == 0 {
                tableView.deleteSections(IndexSet(integer: Section.override.rawValue), with: .automatic)
            }

            tableView.endUpdates()
        }
    }

    public override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        if sourceIndexPath != destinationIndexPath {
            switch Section(rawValue: destinationIndexPath.section)! {
            case .schedule:
                let item = scheduleItems.remove(at: sourceIndexPath.row)
                scheduleItems.insert(item, at: destinationIndexPath.row)

                guard destinationIndexPath.row > 0, let cell = tableView.cellForRow(at: destinationIndexPath) as? GlucoseRangeTableViewCell else {
                    return
                }

                let interval = cell.datePickerInterval
                let startTime = scheduleItems[destinationIndexPath.row - 1].startTime + interval

                scheduleItems[destinationIndexPath.row] = RepeatingScheduleValue(startTime: startTime, value: scheduleItems[destinationIndexPath.row].value)

                // Since the valid date ranges of neighboring cells are affected, the lazy solution is to just reload the entire table view
                DispatchQueue.main.async {
                    tableView.reloadData()
                }
            case .override:
                break
            }
        }
    }

    public override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        switch Section(rawValue: indexPath.section)! {
        case .schedule:
            return true
        case .override:
            return false
        }
    }

    public override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        switch Section(rawValue: indexPath.section)! {
        case .schedule:
            return true
        case .override:
            return false
        }
    }

    public override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .schedule:
            return nil
        case .override:
            return NSLocalizedString("Overrides", comment: "The section title of glucose overrides")
        }
    }

    // MARK: - UITableViewDelegate

    public override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        switch Section(rawValue: indexPath.section)! {
        case .schedule:
            return super.tableView(tableView, shouldHighlightRowAt: indexPath)
        case .override:
            return false
        }
    }

    public override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        switch Section(rawValue: indexPath.section)! {
        case .schedule:
            return super.tableView(tableView, willSelectRowAt: indexPath)
        case .override:
            return nil
        }
    }

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .schedule:
            super.tableView(tableView, didSelectRowAt: indexPath)
        case .override:
            break
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
        if let indexPath = tableView.indexPath(for: cell), let cell = cell as? GlucoseRangeTableViewCell {
            let currentItem = scheduleItems[indexPath.row]

            scheduleItems[indexPath.row] = RepeatingScheduleValue(startTime: currentItem.startTime, value: DoubleRange(minValue: cell.minValue, maxValue: cell.value))
        }
    }

}


extension GlucoseRangeScheduleTableViewController: GlucoseRangeOverrideTableViewCellDelegate {
    func glucoseRangeOverrideTableViewCellDidUpdateValue(_ cell: GlucoseRangeOverrideTableViewCell) {
        guard let indexPath = tableView.indexPath(for: cell) else {
            return
        }

        let context = overrideContexts[indexPath.row]
        overrideRanges[context] = DoubleRange(minValue: cell.minValue, maxValue: cell.maxValue)
    }
}
