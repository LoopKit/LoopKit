//
//  GlucoseRangeScheduleTableViewController.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/13/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit
import HealthKit
import LoopKit

public enum SaveGlucoseRangeScheduleResult {
    case success
    case failure(Error)
}

public protocol GlucoseRangeScheduleStorageDelegate {
    func saveSchedule(for viewController: GlucoseRangeScheduleTableViewController, completion: @escaping (_ result: SaveGlucoseRangeScheduleResult) -> Void)
}

private struct EditableRange {
    public let minValue: Double?
    public let maxValue: Double?

    init(minValue: Double?, maxValue: Double?) {
        self.minValue = minValue
        self.maxValue = maxValue
    }
}

public class GlucoseRangeScheduleTableViewController: UITableViewController {

    public init(allowedValues: [Double], unit: HKUnit, minimumTimeInterval: TimeInterval = TimeInterval(30 * 60)) {
        self.allowedValues = allowedValues
        self.unit = unit
        self.minimumTimeInterval = minimumTimeInterval

        super.init(style: .grouped)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(GlucoseRangeTableViewCell.nib(), forCellReuseIdentifier: GlucoseRangeTableViewCell.className)
        tableView.register(GlucoseRangeOverrideTableViewCell.nib(), forCellReuseIdentifier: GlucoseRangeOverrideTableViewCell.className)
        tableView.register(TextButtonTableViewCell.self, forCellReuseIdentifier: TextButtonTableViewCell.className)

        navigationItem.rightBarButtonItems = [insertButtonItem, editButtonItem]

        updateEditButton()
    }

    @objc private func cancel(_ sender: Any?) {
        self.navigationController?.popViewController(animated: true)
    }

    public private(set) lazy var insertButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addScheduleItem(_:)))
    }()

    private func updateInsertButton() {
        guard let lastItem = editableItems.last else {
            return
        }
        insertButtonItem.isEnabled = !isEditing && lastItem.startTime < lastValidStartTime
    }

    open override func setEditing(_ editing: Bool, animated: Bool) {
        tableView.beginUpdates()
        hideGlucoseRangeCells()
        tableView.endUpdates()

        super.setEditing(editing, animated: animated)

        updateInsertButton()
        updateSaveButton()
    }


    private func updateSaveButton() {
        if let section = sections.firstIndex(of: .save), let cell = tableView.cellForRow(at: IndexPath(row: 0, section: section)) as? TextButtonTableViewCell {
            cell.isEnabled = !isEditing && isScheduleModified && isScheduleValid
        }
    }

    private var isScheduleValid: Bool {
        return !editableItems.isEmpty &&
            editableItems.allSatisfy { isValid($0.value) }
    }

    private func updateEditButton() {
        editButtonItem.isEnabled = editableItems.endIndex > 1
    }

    public func setSchedule(_ schedule: GlucoseRangeSchedule, withOverrideRanges overrides: [TemporaryScheduleOverride.Context: DoubleRange]) {
        unit = schedule.unit
        editableItems = schedule.items.map({ (item) -> RepeatingScheduleValue<EditableRange> in
            let range = EditableRange(minValue: item.value.minValue, maxValue: item.value.maxValue)
            return RepeatingScheduleValue<EditableRange>(startTime: item.startTime, value: range)
        })

        editableOverrideRanges.removeAll()
        for (context, range) in overrides {
            editableOverrideRanges[context] = EditableRange(minValue: range.minValue, maxValue: range.maxValue)
        }

        isScheduleModified = false
    }

    private func isValid(_ range: EditableRange) -> Bool {
        guard let max = range.maxValue, let min = range.minValue, min <= max else {
            return false
        }
        return allowedValues.contains(max) && allowedValues.contains(min)
    }

    @IBAction func addScheduleItem(_ sender: Any?) {

        guard let allowedTimeRange = allowedTimeRange(for: editableItems.count) else {
            return
        }

        editableItems.append(
            RepeatingScheduleValue(
                startTime: allowedTimeRange.lowerBound,
                value: editableItems.last?.value ?? EditableRange(minValue: nil, maxValue: nil)
            )
        )

        tableView.beginUpdates()

        tableView.insertRows(at: [IndexPath(row: editableItems.count - 1, section: Section.schedule.rawValue)], with: .automatic)

        if editableItems.count == 1 {
            tableView.insertSections(IndexSet(integer: Section.override.rawValue), with: .automatic)
        }

        tableView.endUpdates()
    }

    private func updateTimeLimits(for index: Int) {
        let indexPath = IndexPath(row: index, section: Section.schedule.rawValue)
        if let allowedTimeRange = allowedTimeRange(for: index), let cell = tableView.cellForRow(at: indexPath) as? GlucoseRangeTableViewCell {
            cell.allowedTimeRange = allowedTimeRange
        }
    }

    private func allowedTimeRange(for index: Int) -> ClosedRange<TimeInterval>? {
        let minTime: TimeInterval
        let maxTime: TimeInterval
        if index == 0 {
            maxTime = TimeInterval(0)
        } else if index+1 < editableItems.endIndex {
            maxTime = editableItems[index+1].startTime - minimumTimeInterval
        } else {
            maxTime = lastValidStartTime
        }
        if index > 0 {
            minTime = editableItems[index-1].startTime + minimumTimeInterval
            if minTime > lastValidStartTime {
                return nil
            }
        } else {
            minTime = TimeInterval(0)
        }
        return minTime...maxTime
    }

    func insertableIndices(removing row: Int) -> [Bool] {

        let insertableIndices = editableItems.enumerated().map { (enumeration) -> Bool in
            let (index, item) = enumeration

            if row == index {
                return true
            } else if index == 0 {
                return false
            } else if index == editableItems.endIndex - 1 {
                return item.startTime < TimeInterval(hours: 24) - minimumTimeInterval
            } else if index > row {
                return editableItems[index + 1].startTime - item.startTime > minimumTimeInterval
            } else {
                return item.startTime - editableItems[index - 1].startTime > minimumTimeInterval
            }
        }

        return insertableIndices
    }



    // MARK: - State

    public var delegate: GlucoseRangeScheduleStorageDelegate?

    let allowedValues: [Double]
    let minimumTimeInterval: TimeInterval

    var lastValidStartTime: TimeInterval {
        return TimeInterval.hours(24) - minimumTimeInterval
    }

    public var timeZone = TimeZone.currentFixed

    private var unit: HKUnit = HKUnit.milligramsPerDeciliter

    private var isScheduleModified = false {
        didSet {
            if isScheduleModified {
                self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel(_:)))
            } else {
                self.navigationItem.leftBarButtonItem = nil
            }
            updateSaveButton()
        }
    }

    private var editableItems: [RepeatingScheduleValue<EditableRange>] = [] {
        didSet {
            isScheduleModified = true
            updateInsertButton()
            updateEditButton()
        }
    }

    public var schedule: GlucoseRangeSchedule? {
        get {
            let dailyItems = editableItems.compactMap { (item) -> RepeatingScheduleValue<DoubleRange>? in
                guard isValid(item.value) else {
                    return nil
                }
                guard let min = item.value.minValue, let max = item.value.maxValue else {
                    return nil
                }
                let range = DoubleRange(minValue: min, maxValue: max)
                return RepeatingScheduleValue(startTime: item.startTime, value: range)
            }
            return GlucoseRangeSchedule(unit: unit, dailyItems: dailyItems)
        }
    }

    public var overrideContexts: [TemporaryScheduleOverride.Context] = [.preMeal, .legacyWorkout]

    private var editableOverrideRanges: [TemporaryScheduleOverride.Context: EditableRange] = [:] {
        didSet {
            isScheduleModified = true
        }
    }

    public var overrideRanges: [TemporaryScheduleOverride.Context: DoubleRange] {
        get {
            var setRanges: [TemporaryScheduleOverride.Context: DoubleRange] = [:]
            for (context, range) in editableOverrideRanges {
                if let minValue = range.minValue, let maxValue = range.maxValue, isValid(range) {
                    setRanges[context] = DoubleRange(minValue: minValue, maxValue: maxValue)
                }
            }
            return setRanges
        }
    }


    // MARK: - UITableViewDataSource

    private enum Section: Int, CaseIterable {
        case schedule = 0
        case override
        case save
    }

    private var showOverrides: Bool {
        return !editableItems.isEmpty
    }

    private var sections: [Section] {
        if !showOverrides {
            return [.schedule, .save]
        } else {
            return Section.allCases
        }
    }

    public override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .schedule:
            return editableItems.count
        case .override:
            return overrideContexts.count
        case .save:
            return 1
        }
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .schedule:
            let cell = tableView.dequeueReusableCell(withIdentifier: GlucoseRangeTableViewCell.className, for: indexPath) as! GlucoseRangeTableViewCell

            let item = editableItems[indexPath.row]

            cell.timeZone = timeZone
            cell.startTime = item.startTime

            cell.allowedValues = allowedValues

            cell.valueNumberFormatter.minimumFractionDigits = unit.preferredFractionDigits
            cell.valueNumberFormatter.maximumFractionDigits = unit.preferredFractionDigits

            cell.minValue = item.value.minValue
            cell.maxValue = item.value.maxValue
            cell.unitString = unit.shortLocalizedUnitString()
            cell.delegate = self

            if let allowedTimeRange = allowedTimeRange(for: indexPath.row) {
                cell.allowedTimeRange = allowedTimeRange
            }

            return cell
        case .override:
            let cell = tableView.dequeueReusableCell(withIdentifier: GlucoseRangeOverrideTableViewCell.className, for: indexPath) as! GlucoseRangeOverrideTableViewCell

            cell.valueNumberFormatter.minimumFractionDigits = unit.preferredFractionDigits
            cell.valueNumberFormatter.maximumFractionDigits = unit.preferredFractionDigits
            cell.allowedValues = allowedValues

            let context = overrideContexts[indexPath.row]

            if let range = overrideRanges[context], !range.isZero {
                cell.minValue = range.minValue
                cell.maxValue = range.maxValue
            }

            let bundle = Bundle(for: type(of: self))
            let titleText: String
            let image: UIImage?

            switch context {
            case .legacyWorkout:
                titleText = LocalizedString("Workout", comment: "Title for the workout override range")
                image = UIImage(named: "workout", in: bundle, compatibleWith: traitCollection)
            case .preMeal:
                titleText = LocalizedString("Pre-Meal", comment: "Title for the pre-meal override range")
                image = UIImage(named: "Pre-Meal", in: bundle, compatibleWith: traitCollection)
            default:
                preconditionFailure("Unexpected override context \(context)")
            }

            cell.dateLabel.text = titleText
            cell.iconImageView.image = image

            cell.unitString = unit.shortLocalizedUnitString()
            cell.delegate = self

            return cell
        case .save:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath) as! TextButtonTableViewCell

            cell.textLabel?.text = LocalizedString("Save", comment: "Button text for saving glucose correction range schedule")
            cell.isEnabled = isScheduleModified
            return cell
        }
    }

    public override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete, let overrideSectionIndex = sections.firstIndex(of: .override) {
            editableItems.remove(at: indexPath.row)

            tableView.performBatchUpdates({
                tableView.deleteRows(at: [indexPath], with: .automatic)

                if editableItems.isEmpty {
                    tableView.deleteSections(IndexSet(integer: overrideSectionIndex), with: .automatic)
                }
            }, completion: nil)

            if editableItems.count == 1 {
                setEditing(false, animated: true)
            }

            updateSaveButton()
        }
    }

    public override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        if sourceIndexPath != destinationIndexPath {
            switch sections[destinationIndexPath.section] {
            case .schedule:
                let item = editableItems.remove(at: sourceIndexPath.row)
                editableItems.insert(item, at: destinationIndexPath.row)

                guard destinationIndexPath.row > 0 else {
                    return
                }

                let startTime = editableItems[destinationIndexPath.row - 1].startTime + minimumTimeInterval

                editableItems[destinationIndexPath.row] = RepeatingScheduleValue(startTime: startTime, value: editableItems[destinationIndexPath.row].value)

                // Since the valid date ranges of neighboring cells are affected, the lazy solution is to just reload the entire table view
                DispatchQueue.main.async {
                    tableView.reloadData()
                }
            case .override, .save:
                break
            }
        }
    }

    public override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        switch sections[indexPath.section] {
        case .schedule:
            return indexPath.row > 0
        default:
            return false
        }
    }

    public override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        switch sections[indexPath.section] {
        case .schedule:
            return true
        default:
            return false
        }
    }

    public override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch sections[section] {
        case .override:
            return LocalizedString("Overrides", comment: "The section title of glucose overrides")
        default:
            return nil
        }
    }

    public override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch sections[section] {
        case .schedule:
            return LocalizedString("Correction range is the blood glucose range that you would like Loop to correct to.", comment: "The section footer of correction range schedule")
        default:
            return nil
        }
    }

    // MARK: - UITableViewDelegate

    public override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    public override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        tableView.beginUpdates()
        switch sections[indexPath.section] {
        case .schedule:
            updateTimeLimits(for: indexPath.row)
            hideGlucoseRangeCells(excluding: indexPath)
        case .override:
            hideGlucoseRangeCells(excluding: indexPath)
        default:
            break
        }
        tableView.endEditing(false)

        return indexPath
    }

    public override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        tableView.beginUpdates()
        tableView.endUpdates()
    }

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch sections[indexPath.section] {
        case .save:
            delegate?.saveSchedule(for: self, completion: { (result) in
                switch result {
                case .success:
                    self.isScheduleModified = false
                    self.updateInsertButton()
                case .failure(let error):
                    self.present(UIAlertController(with: error), animated: true)
                }
            })
        default:
            break
        }
        tableView.endEditing(false)
        tableView.endUpdates()
        tableView.deselectRow(at: indexPath, animated: true)
    }

    public override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {

        guard sourceIndexPath.section == proposedDestinationIndexPath.section else {
            return sourceIndexPath
        }

        guard sourceIndexPath != proposedDestinationIndexPath else {
            return proposedDestinationIndexPath
        }

        let indices = insertableIndices(removing: sourceIndexPath.row)

        let closestDestinationRow = indices.insertableIndex(closestTo: proposedDestinationIndexPath.row, from: sourceIndexPath.row)
        return IndexPath(row: closestDestinationRow, section: proposedDestinationIndexPath.section)
    }

}

extension GlucoseRangeScheduleTableViewController : GlucoseRangeTableViewCellDelegate {
    func glucoseRangeTableViewCellDidUpdate(_ cell: GlucoseRangeTableViewCell) {
        if let indexPath = tableView.indexPath(for: cell) {
            switch sections[indexPath.section] {
            case .schedule:
                editableItems[indexPath.row] = RepeatingScheduleValue(
                    startTime: cell.startTime,
                    value: EditableRange(minValue: cell.minValue, maxValue: cell.maxValue)
                )
            case .override:
                let context = overrideContexts[indexPath.row]
                editableOverrideRanges[context] = EditableRange(minValue: cell.minValue, maxValue: cell.maxValue)
            default:
                break
            }
        }
    }
}
