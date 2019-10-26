//
//  BasalScheduleTableViewController.swift
//  LoopKitUI
//
//  Created by Pete Schwamb on 2/23/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import UIKit
import HealthKit
import LoopKit

public enum SyncBasalScheduleResult<T: RawRepresentable> {
    case success(scheduleItems: [RepeatingScheduleValue<T>], timeZone: TimeZone)
    case failure(Error)
}


public protocol BasalScheduleTableViewControllerSyncSource: class {
    func syncScheduleValues(for viewController: BasalScheduleTableViewController, completion: @escaping (_ result: SyncBasalScheduleResult<Double>) -> Void)

    func syncButtonTitle(for viewController: BasalScheduleTableViewController) -> String

    func syncButtonDetailText(for viewController: BasalScheduleTableViewController) -> String?

    func basalScheduleTableViewControllerIsReadOnly(_ viewController: BasalScheduleTableViewController) -> Bool
}


open class BasalScheduleTableViewController : DailyValueScheduleTableViewController {

    public init(allowedBasalRates: [Double], maximumScheduleItemCount: Int, minimumTimeInterval: TimeInterval) {
        self.allowedBasalRates = allowedBasalRates
        self.maximumScheduleItemCount = maximumScheduleItemCount
        self.minimumTimeInterval = minimumTimeInterval
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

    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if syncSource == nil {
            delegate?.dailyValueScheduleTableViewControllerWillFinishUpdating(self)
        }
    }

    @objc private func cancel(_ sender: Any?) {
        self.navigationController?.popViewController(animated: true)
    }

    // MARK: - State

    public var scheduleItems: [RepeatingScheduleValue<Double>] = [] {
        didSet {
            updateInsertButton()
        }
    }

    let allowedBasalRates: [Double]
    let maximumScheduleItemCount: Int
    let minimumTimeInterval: TimeInterval

    var lastValidStartTime: TimeInterval {
        return TimeInterval.hours(24) - minimumTimeInterval
    }

    private var isScheduleModified = false {
        didSet {
            if isScheduleModified && syncSource != nil {
                self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel(_:)))
            } else {
                self.navigationItem.leftBarButtonItem = nil
            }
        }
    }

    private func isBasalRateValid(_ value: Double) -> Bool {
        return allowedBasalRates.contains(value)
    }

    private var isSyncAllowed: Bool {
        return !isSyncInProgress && isScheduleValid && !isEditing
    }

    private var isCellReadOnly: Bool {
        return isReadOnly || isSyncInProgress
    }

    private func updateSyncButton() {
        if let cell = tableView.cellForRow(at: IndexPath(row: 0, section: Section.sync.rawValue)) as? TextButtonTableViewCell {
            cell.isEnabled = isSyncAllowed
        }
    }

    private func updateEditButton() {
        editButtonItem.isEnabled = scheduleItems.endIndex > 1
    }

    private func updateInsertButton() {
        guard let lastItem = scheduleItems.last else {
            return
        }
        insertButtonItem.isEnabled = scheduleItems.endIndex < maximumScheduleItemCount && !isEditing && lastItem.startTime < lastValidStartTime
    }

    override func addScheduleItem(_ sender: Any?) {
        guard !isReadOnly && !isSyncInProgress, let firstBasalRate = allowedBasalRates.first else {
            return
        }

        tableView.endEditing(false)

        let startTime: TimeInterval
        let value: Double

        if let lastItem = scheduleItems.last {
            startTime = lastItem.startTime + minimumTimeInterval
            value = lastItem.value

            if startTime > lastValidStartTime {
                return
            }
        } else {
            startTime = TimeInterval(0)
            value = firstBasalRate
        }

        scheduleItems.append(
            RepeatingScheduleValue(
                startTime: startTime,
                value: value
            )
        )
        isScheduleModified = true
        updateTimeLimitsForItemsAdjacent(to: scheduleItems.endIndex-1)

        super.addScheduleItem(sender)

        updateSyncButton()
        updateEditButton()
    }

    override func insertableIndiciesByRemovingRow(_ row: Int, withInterval timeInterval: TimeInterval) -> [Bool] {
        return insertableIndices(for: scheduleItems, removing: row, with: timeInterval)
    }

    open override func setEditing(_ editing: Bool, animated: Bool) {
        tableView.beginUpdates()
        hideSetConstrainedScheduleEntryCells()
        tableView.endUpdates()

        super.setEditing(editing, animated: animated)
        updateInsertButton()
        updateSyncButton()
    }

    public weak var syncSource: BasalScheduleTableViewControllerSyncSource? {
        didSet {
            isReadOnly = syncSource?.basalScheduleTableViewControllerIsReadOnly(self) ?? false

            if isViewLoaded {
                tableView.reloadData()
            }
        }
    }

    private var isSyncInProgress = false {
        didSet {
            for cell in tableView.visibleCells {
                switch cell {
                case let cell as TextButtonTableViewCell:
                    cell.isEnabled = !isSyncInProgress
                    cell.isLoading = isSyncInProgress
                case let cell as SetConstrainedScheduleEntryTableViewCell:
                    cell.isReadOnly = isCellReadOnly
                default:
                    break
                }
            }

            for item in navigationItem.rightBarButtonItems ?? [] {
                item.isEnabled = !isSyncInProgress
            }

            navigationItem.hidesBackButton = isSyncInProgress
        }
    }

    public var isScheduleValid: Bool {
        return !scheduleItems.isEmpty &&
            scheduleItems.count <= maximumScheduleItemCount &&
            scheduleItems.allSatisfy { isBasalRateValid($0.value) }
    }

    private func updateTimeLimitsFor(itemAt index: Int) {
        guard scheduleItems.indices.contains(index) else {
            return
        }
        let indexPath = IndexPath(row: index, section: Section.schedule.rawValue)
        if let cell = tableView.cellForRow(at: indexPath) as? SetConstrainedScheduleEntryTableViewCell {
            if index+1 < scheduleItems.endIndex {
                cell.maximumStartTime = scheduleItems[index+1].startTime - minimumTimeInterval
            } else {
                cell.maximumStartTime = lastValidStartTime
            }
            if index > 1 {
                cell.minimumStartTime = scheduleItems[index-1].startTime + minimumTimeInterval
            }
        }
    }

    private func updateTimeLimitsForItemsAdjacent(to index: Int) {
        updateTimeLimitsFor(itemAt: index-1)
        updateTimeLimitsFor(itemAt: index+1)
    }


    // MARK: - UITableViewDataSource

    private enum Section: Int {
        case schedule
        case sync
    }

    open override func numberOfSections(in tableView: UITableView) -> Int {
        if syncSource != nil {
            return 2
        }

        return 1
    }

    open override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .schedule:
            return scheduleItems.endIndex
        case .sync:
            return 1
        }
    }

    open override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .schedule:
            let cell = tableView.dequeueReusableCell(withIdentifier: SetConstrainedScheduleEntryTableViewCell.className, for: indexPath) as! SetConstrainedScheduleEntryTableViewCell

            cell.unit = HKUnit.internationalUnitsPerHour
            cell.valueQuantityFormatter.numberFormatter.maximumFractionDigits = 3

            let item = scheduleItems[indexPath.row]

            cell.allowedValues = allowedBasalRates
            cell.minimumTimeInterval = minimumTimeInterval
            cell.isReadOnly = isCellReadOnly
            cell.isPickerHidden = true
            cell.delegate = self
            cell.timeZone = timeZone

            if indexPath.row > 0 {
                let lastItem = scheduleItems[indexPath.row - 1]

                cell.minimumStartTime = lastItem.startTime + minimumTimeInterval
            }

            if indexPath.row == 0 {
                cell.maximumStartTime = 0
            } else if indexPath.row < scheduleItems.endIndex - 1 {
                let nextItem = scheduleItems[indexPath.row + 1]
                cell.maximumStartTime = nextItem.startTime - minimumTimeInterval
            } else {
                cell.maximumStartTime = lastValidStartTime
            }

            cell.value = item.value
            cell.startTime = item.startTime

            return cell
        case .sync:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath) as! TextButtonTableViewCell

            cell.textLabel?.text = syncSource?.syncButtonTitle(for: self)
            cell.isEnabled = isSyncAllowed
            cell.isLoading = isSyncInProgress

            return cell
        }
    }

    open override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .schedule:
            return nil
        case .sync:
            return syncSource?.syncButtonDetailText(for: self)
        }
    }

    open override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            scheduleItems.remove(at: indexPath.row)

            super.tableView(tableView, commit: editingStyle, forRowAt: indexPath)

            if scheduleItems.count == 1 {
                self.isEditing = false
            }

            updateSyncButton()
            updateInsertButton()
            updateEditButton()
            updateTimeLimitsFor(itemAt: indexPath.row-1)
            updateTimeLimitsFor(itemAt: indexPath.row)
            isScheduleModified = true

        }
    }

    open override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        if sourceIndexPath != destinationIndexPath {
            let item = scheduleItems.remove(at: sourceIndexPath.row)
            scheduleItems.insert(item, at: destinationIndexPath.row)
            isScheduleModified = true

            guard destinationIndexPath.row > 0, let cell = tableView.cellForRow(at: destinationIndexPath) as? SetConstrainedScheduleEntryTableViewCell else {
                return
            }

            let interval = cell.minimumTimeInterval
            let startTime = scheduleItems[destinationIndexPath.row - 1].startTime + interval

            scheduleItems[destinationIndexPath.row] = RepeatingScheduleValue(startTime: startTime, value: scheduleItems[destinationIndexPath.row].value)

            DispatchQueue.main.async {
                tableView.reloadRows(at: [destinationIndexPath], with: .none)
                self.updateTimeLimitsForItemsAdjacent(to: destinationIndexPath.row)
            }
        }
    }

    // MARK: - UITableViewDelegate

    open override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        guard indexPath.section == 0 else {
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

    open override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return super.tableView(tableView, canEditRowAt: indexPath) && !isSyncInProgress
    }

    open override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        super.tableView(tableView, didSelectRowAt: indexPath)

        switch Section(rawValue: indexPath.section)! {
        case .schedule:
            break
        case .sync:
            if let syncSource = syncSource, !isSyncInProgress {
                isSyncInProgress = true
                syncSource.syncScheduleValues(for: self) { (result) in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let items, let timeZone):
                            self.scheduleItems = items
                            self.timeZone = timeZone
                            self.tableView.reloadSections([Section.schedule.rawValue], with: .fade)
                            self.isSyncInProgress = false
                            self.delegate?.dailyValueScheduleTableViewControllerWillFinishUpdating(self)
                            self.isScheduleModified = false
                            self.updateInsertButton()
                        case .failure(let error):
                            self.present(UIAlertController(with: error), animated: true) {
                                self.isSyncInProgress = false
                            }
                        }
                    }
                }
            }
        }
    }

    open override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {

        guard sourceIndexPath != proposedDestinationIndexPath, let cell = tableView.cellForRow(at: sourceIndexPath) as? SetConstrainedScheduleEntryTableViewCell else {
            return proposedDestinationIndexPath
        }

        let interval = cell.minimumTimeInterval
        let indices = insertableIndices(for: scheduleItems, removing: sourceIndexPath.row, with: interval)

        let closestDestinationRow = indices.insertableIndex(closestTo: proposedDestinationIndexPath.row, from: sourceIndexPath.row)
        return IndexPath(row: closestDestinationRow, section: proposedDestinationIndexPath.section)
    }
}

extension BasalScheduleTableViewController: SetConstrainedScheduleEntryTableViewCellDelegate {
    func setConstrainedScheduleEntryTableViewCellDidUpdate(_ cell: SetConstrainedScheduleEntryTableViewCell) {
        guard let value = cell.value else {
            return
        }
        if let indexPath = tableView.indexPath(for: cell) {
            isScheduleModified = true
            scheduleItems[indexPath.row] = RepeatingScheduleValue(
                startTime: cell.startTime,
                value: value
            )
            updateTimeLimitsForItemsAdjacent(to: indexPath.row)
            updateSyncButton()
        }
    }
}
