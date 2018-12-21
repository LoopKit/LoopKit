//
//  MockPumpManagerSettingsViewController.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 11/20/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit
import HealthKit
import LoopKit
import LoopKitUI
import MockKit


final class MockPumpManagerSettingsViewController: UITableViewController {

    let pumpManager: MockPumpManager

    init(pumpManager: MockPumpManager) {
        self.pumpManager = pumpManager
        super.init(style: .grouped)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var suspendResumeTableViewCell: SuspendResumeTableViewCell = { [unowned self] in
        let cell = SuspendResumeTableViewCell(style: .default, reuseIdentifier: nil)
        cell.delegate = self
        cell.suspendState = pumpManager.status.suspendState
        pumpManager.addStatusObserver(cell)
        return cell
    }()

    private let quantityFormatter = QuantityFormatter()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Pump Settings"

        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44

        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.estimatedSectionHeaderHeight = 55

        tableView.register(SettingsTableViewCell.self, forCellReuseIdentifier: SettingsTableViewCell.className)
        tableView.register(SwitchTableViewCell.nib(), forCellReuseIdentifier: SwitchTableViewCell.className)
        tableView.register(TextButtonTableViewCell.self, forCellReuseIdentifier: TextButtonTableViewCell.className)
    }

    // MARK: - Data Source

    private enum Section: Int, CaseIterable {
        case actions = 0
        case settings
        case deleteHealthData
        case deletePump
    }

    private enum ActionRow: Int, CaseIterable {
        case suspendResume = 0
    }

    private enum SettingsRow: Int, CaseIterable {
        case reservoirRemaining = 0
        case batteryRemaining
        case tempBasalErrorToggle
        case bolusErrorToggle
        case suspendErrorToggle
        case resumeErrorToggle
    }

    // MARK: UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .actions:
            return ActionRow.allCases.count
        case .settings:
            return SettingsRow.allCases.count
        case .deleteHealthData, .deletePump:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .actions:
            return nil
        case .settings:
            return "Configuration"
        case .deleteHealthData, .deletePump:
            return " "  // Use an empty string for more dramatic spacing
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .actions:
            switch ActionRow(rawValue: indexPath.row)! {
            case .suspendResume:
                return suspendResumeTableViewCell
            }
        case .settings:
            switch SettingsRow(rawValue: indexPath.row)! {
            case .reservoirRemaining:
                let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
                cell.textLabel?.text = "Reservoir Remaining"
                cell.detailTextLabel?.text = quantityFormatter.string(from: HKQuantity(unit: .internationalUnit(), doubleValue: pumpManager.state.reservoirUnitsRemaining), for: .internationalUnit())
                cell.accessoryType = .disclosureIndicator
                return cell
            case .batteryRemaining:
                let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
                cell.textLabel?.text = "Battery Remaining"
                if let remainingCharge = pumpManager.status.pumpBatteryChargeRemaining {
                    cell.detailTextLabel?.text = "\(Int(round(remainingCharge * 100)))%"
                } else {
                    cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
                }
                cell.accessoryType = .disclosureIndicator
                return cell
            case .tempBasalErrorToggle:
                return switchTableViewCell(for: indexPath, titled: "Error on Temp Basal", boundTo: \.tempBasalEnactmentShouldError)
            case .bolusErrorToggle:
                return switchTableViewCell(for: indexPath, titled: "Error on Bolus", boundTo: \.bolusEnactmentShouldError)
            case .suspendErrorToggle:
                return switchTableViewCell(for: indexPath, titled: "Error on Suspend", boundTo: \.deliverySuspensionShouldError)
            case .resumeErrorToggle:
                return switchTableViewCell(for: indexPath, titled: "Error on Resume", boundTo: \.deliveryResumptionShouldError)
            }
        case .deleteHealthData:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath) as! TextButtonTableViewCell
            cell.textLabel?.text = "Delete Health Data"
            cell.textLabel?.textAlignment = .center
            cell.tintColor = .delete
            cell.isEnabled = true
            return cell
        case .deletePump:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath) as! TextButtonTableViewCell
            cell.textLabel?.text = "Delete Pump"
            cell.textLabel?.textAlignment = .center
            cell.tintColor = .delete
            cell.isEnabled = true
            return cell
        }
    }

    private func switchTableViewCell(for indexPath: IndexPath, titled title: String, boundTo keyPath: WritableKeyPath<MockPumpManagerState, Bool>) -> SwitchTableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SwitchTableViewCell.className, for: indexPath) as! SwitchTableViewCell
        cell.titleLabel?.text = title
        cell.switch?.isOn = pumpManager.state[keyPath: keyPath]
        cell.onToggle = { [unowned pumpManager] isOn in
            pumpManager.state[keyPath: keyPath] = isOn
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let sender = tableView.cellForRow(at: indexPath)

        switch Section(rawValue: indexPath.section)! {
        case .actions:
            switch ActionRow(rawValue: indexPath.row)! {
            case .suspendResume:
                suspendResumeTableViewCell.toggle()
                tableView.deselectRow(at: indexPath, animated: true)
            }
        case .settings:
            switch SettingsRow(rawValue: indexPath.row)! {
            case .reservoirRemaining:
                let vc = TextFieldTableViewController()
                vc.value = String(format: "%.1f", pumpManager.state.reservoirUnitsRemaining)
                vc.unit = "U"
                vc.keyboardType = .decimalPad
                vc.indexPath = indexPath
                vc.delegate = self
                show(vc, sender: sender)
            case .batteryRemaining:
                let vc = PercentageTextFieldTableViewController()
                vc.percentage = pumpManager.status.pumpBatteryChargeRemaining
                vc.indexPath = indexPath
                vc.percentageDelegate = self
                show(vc, sender: sender)
            case .tempBasalErrorToggle, .bolusErrorToggle, .suspendErrorToggle, .resumeErrorToggle:
                break
            }
        case .deleteHealthData:
            let confirmVC = UIAlertController(healthDataDeletionHandler: pumpManager.deletePumpData)
            present(confirmVC, animated: true) {
                tableView.deselectRow(at: indexPath, animated: true)
            }
        case .deletePump:
            let confirmVC = UIAlertController(pumpDeletionHandler: {
                self.pumpManager.pumpManagerDelegate?.pumpManagerWillDeactivate(self.pumpManager)
                self.navigationController?.popViewController(animated: true)
            })

            present(confirmVC, animated: true) {
                tableView.deselectRow(at: indexPath, animated: true)
            }
        }
    }
}

extension MockPumpManagerSettingsViewController: SuspendResumeTableViewCellDelegate {
    func suspendTapped() {
        pumpManager.suspendDelivery { result in
            if case .failure(let error) = result {
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Error Suspending", error: error)
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
    }

    func resumeTapped() {
        pumpManager.resumeDelivery { result in
            if case .failure(let error) = result {
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Error Resuming", error: error)
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
    }
}

extension MockPumpManagerSettingsViewController: TextFieldTableViewControllerDelegate {
    func textFieldTableViewControllerDidReturn(_ controller: TextFieldTableViewController) {
        update(from: controller)
    }

    func textFieldTableViewControllerDidEndEditing(_ controller: TextFieldTableViewController) {
        update(from: controller)
    }

    private func update(from controller: TextFieldTableViewController) {
        guard let indexPath = controller.indexPath else { assertionFailure(); return }
        assert(indexPath == [Section.settings.rawValue, SettingsRow.reservoirRemaining.rawValue])
        if let value = controller.value.flatMap(Double.init) {
            pumpManager.state.reservoirUnitsRemaining = value
        }
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
}

extension MockPumpManagerSettingsViewController: PercentageTextFieldTableViewControllerDelegate {
    func percentageTextFieldTableViewControllerDidChangePercentage(_ controller: PercentageTextFieldTableViewController) {
        guard let indexPath = controller.indexPath else { assertionFailure(); return }
        assert(indexPath == [Section.settings.rawValue, SettingsRow.batteryRemaining.rawValue])
        pumpManager.status.pumpBatteryChargeRemaining = controller.percentage.map { $0.clamped(to: 0...1) }
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
}

private extension UIAlertController {
    convenience init(healthDataDeletionHandler handler: @escaping () -> Void) {
        self.init(
            title: nil,
            message: "Are you sure you want to delete mock pump health data?",
            preferredStyle: .actionSheet
        )

        addAction(UIAlertAction(
            title: "Delete Health Data",
            style: .destructive,
            handler: { _ in handler() }
        ))

        addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    }

    convenience init(pumpDeletionHandler handler: @escaping () -> Void) {
        self.init(
            title: nil,
            message: "Are you sure you want to delete this pump?",
            preferredStyle: .actionSheet
        )

        addAction(UIAlertAction(
            title: "Delete Pump",
            style: .destructive,
            handler: { _ in handler() }
        ))

        addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    }
}
