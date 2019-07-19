//
//  InsulinSensitivityScheduleViewController.swift
//  LoopKitUI
//
//  Created by Pete Schwamb on 7/2/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import UIKit
import HealthKit
import LoopKit

public enum SaveInsulinSensitivityScheduleResult {
    case success
    case failure(Error)
}

public protocol InsulinSensitivityScheduleStorageDelegate {
    func saveSchedule(_ schedule: InsulinSensitivitySchedule, for viewController: InsulinSensitivityScheduleViewController, completion: @escaping (_ result: SaveInsulinSensitivityScheduleResult) -> Void)
}

public class InsulinSensitivityScheduleViewController : DailyValueScheduleTableViewController {

    public init(allowedValues: [Double], unit: HKUnit, minimumTimeInterval: TimeInterval = TimeInterval(30 * 60)) {
        self.allowedValues = allowedValues
        self.minimumTimeInterval = minimumTimeInterval
        self.unit = unit

        super.init(style: .grouped)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(SetConstrainedScheduleEntryTableViewCell.nib(), forCellReuseIdentifier: SetConstrainedScheduleEntryTableViewCell.className)
        tableView.register(TextButtonTableViewCell.self, forCellReuseIdentifier: TextButtonTableViewCell.className)
        updateEditButton()
    }

    @objc private func cancel(_ sender: Any?) {
        self.navigationController?.popViewController(animated: true)
    }

    // MARK: - State

    public var insulinSensitivityScheduleStorageDelegate: InsulinSensitivityScheduleStorageDelegate?

    public var unit: HKUnit = HKUnit.milligramsPerDeciliter.unitDivided(by: .internationalUnit())

    public var schedule: InsulinSensitivitySchedule? {
        get {
            let validEntries = internalItems.compactMap { (item) -> RepeatingScheduleValue<Double>? in
                guard let value = item.value else {
                    return nil
                }
                return RepeatingScheduleValue(startTime: item.startTime, value: value)
            }
            return InsulinSensitivitySchedule(unit: unit, dailyItems: validEntries, timeZone: timeZone)
        }
        set {
            if let newValue = newValue {
                unit = newValue.unit
                internalItems = newValue.items.map { (entry) -> RepeatingScheduleValue<Double?> in
                    RepeatingScheduleValue(startTime: entry.startTime, value: entry.value)
                }
                isScheduleModified = false
            } else {
                internalItems = []
            }
        }
    }

    private var internalItems: [RepeatingScheduleValue<Double?>] = [] {
        didSet {
            isScheduleModified = true
            updateInsertButton()
        }
    }

    let allowedValues: [Double]
    let minimumTimeInterval: TimeInterval

    var lastValidStartTime: TimeInterval {
        return TimeInterval.hours(24) - minimumTimeInterval
    }

    private var isScheduleModified = false {
        didSet {
            updateCancelButton()
            updateSaveButton()
        }
    }

    private func isValid(_ value: Double?) -> Bool {
        guard let value = value else {
            return false
        }
        return allowedValues.contains(value)
    }

    public var isScheduleValid: Bool {
        return !internalItems.isEmpty &&
            internalItems.allSatisfy { isValid($0.value) }
    }

    private func updateCancelButton() {
        if isScheduleModified {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel(_:)))
        } else {
            self.navigationItem.leftBarButtonItem = nil
        }
    }

    private func updateSaveButton() {
        if let cell = tableView.cellForRow(at: IndexPath(row: 0, section: Section.save.rawValue)) as? TextButtonTableViewCell {
            cell.isEnabled = !isEditing && isScheduleModified && isScheduleValid
        }
    }

    private func updateEditButton() {
        editButtonItem.isEnabled = internalItems.endIndex > 1
    }

    private func updateInsertButton() {
        guard let lastItem = internalItems.last else {
            return
        }
        insertButtonItem.isEnabled = !isEditing && lastItem.startTime < lastValidStartTime
    }

    override func addScheduleItem(_ sender: Any?) {
        tableView.endEditing(false)

        let startTime: TimeInterval
        let value: Double?

        if let lastItem = internalItems.last {
            startTime = lastItem.startTime + minimumTimeInterval
            value = lastItem.value

            if startTime > lastValidStartTime {
                return
            }
        } else {
            startTime = TimeInterval(0)
            value = nil
        }

        internalItems.append(
            RepeatingScheduleValue(
                startTime: startTime,
                value: value
            )
        )
        updateTimeLimitsForItemsAdjacent(to: internalItems.endIndex-1)

        super.addScheduleItem(sender)

        if internalItems.count == 1 {
            let index = IndexPath(row: 0, section: Section.schedule.rawValue)
            tableView.beginUpdates()
            tableView.selectRow(at: index, animated: true, scrollPosition: .top)
            tableView.deselectRow(at: index, animated: true)
            tableView.endUpdates()
        } else {
            tableView.beginUpdates()
            hideSetConstrainedScheduleEntryCells()
            tableView.endUpdates()
        }

        updateEditButton()
    }

    override func insertableIndiciesByRemovingRow(_ row: Int, withInterval timeInterval: TimeInterval) -> [Bool] {
        return insertableIndices(for: internalItems, removing: row, with: timeInterval)
    }

    open override func setEditing(_ editing: Bool, animated: Bool) {
        tableView.beginUpdates()
        hideSetConstrainedScheduleEntryCells()
        tableView.endUpdates()

        super.setEditing(editing, animated: animated)
        updateInsertButton()
        updateSaveButton()
    }


    private func updateTimeLimitsFor(itemAt index: Int) {
        guard internalItems.indices.contains(index) else {
            return
        }
        let indexPath = IndexPath(row: index, section: Section.schedule.rawValue)
        if let cell = tableView.cellForRow(at: indexPath) as? SetConstrainedScheduleEntryTableViewCell {
            if index+1 < internalItems.endIndex {
                cell.maximumStartTime = internalItems[index+1].startTime - minimumTimeInterval
            } else {
                cell.maximumStartTime = lastValidStartTime
            }
            if index > 1 {
                cell.minimumStartTime = internalItems[index-1].startTime + minimumTimeInterval
            }
        }
    }

    private func updateTimeLimitsForItemsAdjacent(to index: Int) {
        updateTimeLimitsFor(itemAt: index-1)
        updateTimeLimitsFor(itemAt: index+1)
    }


    // MARK: - UITableViewDataSource

    private enum Section: Int, CaseIterable {
        case schedule
        case save
    }

    open override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    open override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .schedule:
            return internalItems.endIndex
        case .save:
            return 1
        }
    }

    open override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .schedule:
            let cell = tableView.dequeueReusableCell(withIdentifier: SetConstrainedScheduleEntryTableViewCell.className, for: indexPath) as! SetConstrainedScheduleEntryTableViewCell

            cell.unit = unit.unitDivided(by: .internationalUnit())

            let item = internalItems[indexPath.row]

            cell.allowedValues = allowedValues
            cell.minimumTimeInterval = minimumTimeInterval
            cell.isReadOnly = false
            cell.isPickerHidden = true
            cell.delegate = self
            cell.timeZone = timeZone

            if indexPath.row > 0 {
                let lastItem = internalItems[indexPath.row - 1]

                cell.minimumStartTime = lastItem.startTime + minimumTimeInterval
            }

            if indexPath.row == 0 {
                cell.maximumStartTime = 0
            } else if indexPath.row < internalItems.endIndex - 1 {
                let nextItem = internalItems[indexPath.row + 1]
                cell.maximumStartTime = nextItem.startTime - minimumTimeInterval
            } else {
                cell.maximumStartTime = lastValidStartTime
            }

            cell.value = item.value
            cell.startTime = item.startTime
            cell.emptySelectionType = .lastIndex

            return cell
        case .save:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath) as! TextButtonTableViewCell
            cell.textLabel?.text = LocalizedString("Save", comment: "Button text for saving insulin sensitivity schedule")
            cell.isEnabled = isScheduleModified && isScheduleValid

            return cell
        }
    }

    open override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .schedule:
            return LocalizedString("Insulin sensitivity describes how your blood glucose should respond to a 1 Unit dose of insulin. Smaller values mean more insulin will be given when above target. Values that are too small can cause dangerously low blood glucose.", comment: "The description shown on the insulin sensitivity schedule interface.")
        case .save:
            return nil
        }
    }

    open override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            internalItems.remove(at: indexPath.row)

            super.tableView(tableView, commit: editingStyle, forRowAt: indexPath)

            if internalItems.count == 1 {
                self.isEditing = false
            }

            updateInsertButton()
            updateEditButton()
            updateTimeLimitsFor(itemAt: indexPath.row-1)
            updateTimeLimitsFor(itemAt: indexPath.row)
            updateSaveButton()
        }
    }

    open override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        if sourceIndexPath != destinationIndexPath {
            let item = internalItems.remove(at: sourceIndexPath.row)
            internalItems.insert(item, at: destinationIndexPath.row)

            let startTime = internalItems[destinationIndexPath.row - 1].startTime + minimumTimeInterval

            internalItems[destinationIndexPath.row] = RepeatingScheduleValue(startTime: startTime, value: internalItems[destinationIndexPath.row].value)

            DispatchQueue.main.async {
                tableView.reloadRows(at: [destinationIndexPath], with: .none)
                self.updateTimeLimitsForItemsAdjacent(to: destinationIndexPath.row)
            }
        }
    }

    // MARK: - UITableViewDelegate

    open override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        guard indexPath.section == Section.schedule.rawValue else {
            return super.tableView(tableView, shouldHighlightRowAt: indexPath)
        }

        return !isReadOnly
    }

    open override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        tableView.beginUpdates()
        hideSetConstrainedScheduleEntryCells(excluding: indexPath)
        tableView.endUpdates()
        return super.tableView(tableView, willSelectRowAt: indexPath)
    }

    open override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        super.tableView(tableView, didSelectRowAt: indexPath)

        switch Section(rawValue: indexPath.section)! {
        case .schedule:
            break
        case .save:
            if let schedule = schedule {
                insulinSensitivityScheduleStorageDelegate?.saveSchedule(schedule, for: self, completion: { (result) in
                    switch result {
                    case .success:
                        self.delegate?.dailyValueScheduleTableViewControllerWillFinishUpdating(self)
                        self.isScheduleModified = false
                        self.updateInsertButton()
                    case .failure(let error):
                        self.present(UIAlertController(with: error), animated: true)
                    }
                })
            }
        }
    }

    open override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {

        guard sourceIndexPath != proposedDestinationIndexPath, let cell = tableView.cellForRow(at: sourceIndexPath) as? SetConstrainedScheduleEntryTableViewCell else {
            return proposedDestinationIndexPath
        }

        let interval = cell.minimumTimeInterval
        let indices = insertableIndices(for: internalItems, removing: sourceIndexPath.row, with: interval)

        let closestDestinationRow = indices.insertableIndex(closestTo: proposedDestinationIndexPath.row, from: sourceIndexPath.row)
        return IndexPath(row: closestDestinationRow, section: proposedDestinationIndexPath.section)
    }
}

extension InsulinSensitivityScheduleViewController: SetConstrainedScheduleEntryTableViewCellDelegate {
    func setConstrainedScheduleEntryTableViewCellDidUpdate(_ cell: SetConstrainedScheduleEntryTableViewCell) {
        if let indexPath = tableView.indexPath(for: cell) {
            internalItems[indexPath.row] = RepeatingScheduleValue(
                startTime: cell.startTime,
                value: cell.value
            )
            updateTimeLimitsForItemsAdjacent(to: indexPath.row)
        }
    }
}
