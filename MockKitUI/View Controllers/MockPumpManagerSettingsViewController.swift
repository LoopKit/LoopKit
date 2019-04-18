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
        tableView.register(SuspendResumeTableViewCell.self, forCellReuseIdentifier: SuspendResumeTableViewCell.className)

        pumpManager.addStatusObserver(self, queue: .main)

        let button = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped(_:)))
        self.navigationItem.setRightBarButton(button, animated: false)
    }

    @objc func doneTapped(_ sender: Any) {
        done()
    }

    private func done() {
        if let nav = navigationController as? SettingsNavigationViewController {
            nav.notifyComplete()
        }
        if let nav = navigationController as? MockPumpManagerSetupViewController {
            nav.finishedSettingsDisplay()
        }
    }

    // MARK: - Data Source

    private enum Section: Int, CaseIterable {
        case actions = 0
        case settings
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
        case .deletePump:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .actions:
            return nil
        case .settings:
            return "Configuration"
        case .deletePump:
            return " "  // Use an empty string for more dramatic spacing
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .actions:
            switch ActionRow(rawValue: indexPath.row)! {
            case .suspendResume:
                let cell = tableView.dequeueReusableCell(withIdentifier: SuspendResumeTableViewCell.className, for: indexPath) as! SuspendResumeTableViewCell
                cell.basalDeliveryState = pumpManager.status.basalDeliveryState
                return cell
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
                if let suspendResumeCell = sender as? SuspendResumeTableViewCell {
                    suspendResumeCellTapped(suspendResumeCell)
                }
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
        case .deletePump:
            let confirmVC = UIAlertController(pumpDeletionHandler: {
                self.pumpManager.notifyDelegateOfDeactivation {
                    DispatchQueue.main.async {
                        self.done()
                    }
                }
            })

            present(confirmVC, animated: true) {
                tableView.deselectRow(at: indexPath, animated: true)
            }
        }
    }

    private func suspendResumeCellTapped(_ cell: SuspendResumeTableViewCell) {
        switch cell.shownAction {
        case .resume:
            pumpManager.resumeDelivery { (error) in
                if let error = error {
                    DispatchQueue.main.async {
                        let title = LocalizedString("Error Resuming", comment: "The alert title for a resume error")
                        self.present(UIAlertController(with: error, title: title), animated: true)
                    }
                }
            }
        case .suspend:
            pumpManager.suspendDelivery { (error) in
                if let error = error {
                    DispatchQueue.main.async {
                        let title = LocalizedString("Error Suspending", comment: "The alert title for a suspend error")
                        self.present(UIAlertController(with: error, title: title), animated: true)
                    }
                }
            }
        }
    }
}

extension MockPumpManagerSettingsViewController: PumpManagerStatusObserver {
    public func pumpManager(_ pumpManager: PumpManager, didUpdate status: PumpManagerStatus, oldStatus: PumpManagerStatus) {
        dispatchPrecondition(condition: .onQueue(.main))

        if let suspendResumeTableViewCell = self.tableView?.cellForRow(at: IndexPath(row: ActionRow.suspendResume.rawValue, section: Section.actions.rawValue)) as? SuspendResumeTableViewCell
        {
            suspendResumeTableViewCell.basalDeliveryState = status.basalDeliveryState
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

    convenience init(title: String, error: Error) {

        let message: String

        if let localizedError = error as? LocalizedError {
            let sentenceFormat = NSLocalizedString("%@.", comment: "Appends a full-stop to a statement")
            message = [localizedError.failureReason, localizedError.recoverySuggestion].compactMap({ $0 }).map({
                String(format: sentenceFormat, $0)
            }).joined(separator: "\n")
        } else {
            message = String(describing: error)
        }

        self.init(
            title: title,
            message: message,
            preferredStyle: .alert
        )

        addAction(UIAlertAction(
            title: NSLocalizedString("OK", comment: "Button title to acknowledge error"),
            style: .default,
            handler: nil
        ))
    }
}
