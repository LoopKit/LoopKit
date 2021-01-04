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
import SwiftUI


final class MockPumpManagerSettingsViewController: UITableViewController {

    let pumpManager: MockPumpManager
    let supportedInsulinTypes: [InsulinType]

    init(pumpManager: MockPumpManager, supportedInsulinTypes: [InsulinType]) {
        self.pumpManager = pumpManager
        self.supportedInsulinTypes = supportedInsulinTypes
        super.init(style: .grouped)
        title = NSLocalizedString("Pump Settings", comment: "Title for Pump simulator settings")
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private let quantityFormatter = QuantityFormatter()

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44

        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.estimatedSectionHeaderHeight = 55

        tableView.register(DateAndDurationTableViewCell.nib(), forCellReuseIdentifier: DateAndDurationTableViewCell.className)
        tableView.register(SegmentedControlTableViewCell.self, forCellReuseIdentifier: SegmentedControlTableViewCell.className)
        tableView.register(SettingsTableViewCell.self, forCellReuseIdentifier: SettingsTableViewCell.className)
        tableView.register(BoundSwitchTableViewCell.self, forCellReuseIdentifier: BoundSwitchTableViewCell.className)
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
        case basalRate = 0
        case actions
        case settings
        case statusProgress
        case deletePump
    }

    private enum ActionRow: Int, CaseIterable {
        case suspendResume = 0
        case occlusion
        case pumpError
    }

    private enum SettingsRow: Int, CaseIterable {
        case deliverableIncrements = 0
        case supportedBasalRates
        case supportedBolusVolumes
        case insulinType
        case reservoirRemaining
        case batteryRemaining
        case tempBasalErrorToggle
        case bolusErrorToggle
        case bolusCancelErrorToggle
        case suspendErrorToggle
        case resumeErrorToggle
        case uncertainDeliveryErrorToggle
        case lastReconciliationDate
    }
    
    private enum StatusProgressRow: Int, CaseIterable {
        case percentComplete
        case warningThreshold
        case criticalThreshold
    }

    // MARK: UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .basalRate:
            return 1
        case .actions:
            return ActionRow.allCases.count
        case .settings:
            return SettingsRow.allCases.count
        case .statusProgress:
            return StatusProgressRow.allCases.count
        case .deletePump:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .basalRate:
            return nil
        case .actions:
            return nil
        case .settings:
            return "Configuration"
        case .statusProgress:
            return "Status Progress"
        case .deletePump:
            return " "  // Use an empty string for more dramatic spacing
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .basalRate:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
            cell.textLabel?.text = "Current Basal Rate"
            if let currentBasalRate = pumpManager.currentBasalRate {
                cell.detailTextLabel?.text = quantityFormatter.string(from: currentBasalRate, for: HKUnit.internationalUnit().unitDivided(by: .hour()))
            } else {
                cell.detailTextLabel?.text = "—"
            }
            cell.isUserInteractionEnabled = false
            return cell
        case .actions:
            switch ActionRow(rawValue: indexPath.row)! {
            case .suspendResume:
                let cell = tableView.dequeueReusableCell(withIdentifier: SuspendResumeTableViewCell.className, for: indexPath) as! SuspendResumeTableViewCell
                cell.basalDeliveryState = pumpManager.status.basalDeliveryState
                return cell
            case .occlusion:
                let cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath) as! TextButtonTableViewCell
                if pumpManager.state.occlusionDetected {
                    cell.textLabel?.text = "Resolve Occlusion"
                } else {
                    cell.textLabel?.text = "Detect Occlusion"
                }
                return cell
            case .pumpError:
                let cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath) as! TextButtonTableViewCell
                if pumpManager.state.pumpErrorDetected {
                    cell.textLabel?.text = "Resolve Pump Error"
                } else {
                    cell.textLabel?.text = "Cause Pump Error"
                }
                return cell
            }
        case .settings:
            switch SettingsRow(rawValue: indexPath.row)! {
            case .deliverableIncrements:
                let cell = tableView.dequeueReusableCell(withIdentifier: SegmentedControlTableViewCell.className, for: indexPath) as! SegmentedControlTableViewCell
                let possibleDeliverableIncrements = MockPumpManagerState.DeliverableIncrements.allCases
                cell.textLabel?.text = "Increments"
                cell.options = possibleDeliverableIncrements.map { increments in
                    switch increments {
                    case .omnipod:
                        return "Pod"
                    case .medtronicX22:
                        return "x22"
                    case .medtronicX23:
                        return "x23"
                    case .custom:
                        return "Custom"
                    }
                }
                cell.segmentedControl.selectedSegmentIndex = possibleDeliverableIncrements.firstIndex(of: pumpManager.state.deliverableIncrements)!
                cell.onSelection { [pumpManager] index in
                    pumpManager.state.deliverableIncrements = possibleDeliverableIncrements[index]
                    tableView.reloadRows(at: [IndexPath(row: SettingsRow.supportedBasalRates.rawValue, section: Section.settings.rawValue), IndexPath(row: SettingsRow.supportedBolusVolumes.rawValue, section: Section.settings.rawValue)], with: .automatic)
                }
                return cell
            case .supportedBasalRates:
                let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
                cell.textLabel?.text = "Basal Rates"
                cell.detailTextLabel?.text = pumpManager.state.supportedBasalRatesDescription
                if pumpManager.state.deliverableIncrements == .custom {
                    cell.accessoryType = .disclosureIndicator
                }
                return cell
            case .supportedBolusVolumes:
                let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
                cell.textLabel?.text = "Bolus Volumes"
                cell.detailTextLabel?.text = pumpManager.state.supportedBolusVolumesDescription
                if pumpManager.state.deliverableIncrements == .custom {
                    cell.accessoryType = .disclosureIndicator
                }
                return cell
            case .insulinType:
                let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
                cell.prepareForReuse()
                cell.textLabel?.text = "Insulin Type"
                cell.detailTextLabel?.text = pumpManager.state.insulinType.brandName
                cell.accessoryType = .disclosureIndicator
                return cell
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
            case .bolusCancelErrorToggle:
                return switchTableViewCell(for: indexPath, titled: "Error on Cancel Bolus", boundTo: \.bolusCancelShouldError)
            case .suspendErrorToggle:
                return switchTableViewCell(for: indexPath, titled: "Error on Suspend", boundTo: \.deliverySuspensionShouldError)
            case .resumeErrorToggle:
                return switchTableViewCell(for: indexPath, titled: "Error on Resume", boundTo: \.deliveryResumptionShouldError)
            case .uncertainDeliveryErrorToggle:
                return switchTableViewCell(for: indexPath, titled: "Next Delivery Command Uncertain", boundTo: \.deliveryCommandsShouldTriggerUncertainDelivery)
            case .lastReconciliationDate:
                let cell = tableView.dequeueReusableCell(withIdentifier: DateAndDurationTableViewCell.className, for: indexPath) as! DateAndDurationTableViewCell
                cell.titleLabel.text = "Last Reconciliation Date"
                cell.date = pumpManager.lastReconciliation ?? Date()
                cell.datePicker.maximumDate = Date()
                cell.datePicker.minimumDate = Date() - .hours(48)
                cell.datePicker.datePickerMode = .dateAndTime
                #if swift(>=5.2)
                    if #available(iOS 14.0, *) {
                        cell.datePicker.preferredDatePickerStyle = .wheels
                    }
                #endif
                cell.datePicker.isEnabled = true
                cell.delegate = self
                return cell
            }
        case .statusProgress:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
            switch StatusProgressRow(rawValue: indexPath.row)! {
            case .percentComplete:
                cell.textLabel?.text = "Percent Completed"
                if let percentCompleted = pumpManager.state.progressPercentComplete {
                    cell.detailTextLabel?.text = "\(Int(round(percentCompleted * 100)))%"
                } else {
                    cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
                }
            case .warningThreshold:
                cell.textLabel?.text = "Warning Threshold"
                if let warningThreshold = pumpManager.state.progressWarningThresholdPercentValue {
                    cell.detailTextLabel?.text = "\(Int(round(warningThreshold * 100)))%"
                } else {
                    cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
                }
            case .criticalThreshold:
                cell.textLabel?.text = "Critical Threshold"
                if let criticalThreshold = pumpManager.state.progressCriticalThresholdPercentValue {
                    cell.detailTextLabel?.text = "\(Int(round(criticalThreshold * 100)))%"
                } else {
                    cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
                }
            }
            cell.accessoryType = .disclosureIndicator
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
        let cell = tableView.dequeueReusableCell(withIdentifier: BoundSwitchTableViewCell.className, for: indexPath) as! BoundSwitchTableViewCell
        cell.textLabel?.text = title
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
            case .occlusion:
                pumpManager.state.occlusionDetected = !pumpManager.state.occlusionDetected
                tableView.deselectRow(at: indexPath, animated: true)
                tableView.reloadRows(at: [indexPath], with: .automatic)
            case .pumpError:
                pumpManager.state.pumpErrorDetected = !pumpManager.state.pumpErrorDetected
                tableView.deselectRow(at: indexPath, animated: true)
                tableView.reloadRows(at: [indexPath], with: .automatic)
            }
        case .settings:
            tableView.deselectRow(at: indexPath, animated: true)
            switch SettingsRow(rawValue: indexPath.row)! {
            case .deliverableIncrements:
                break
            case .supportedBasalRates:
                if pumpManager.state.deliverableIncrements == .custom, pumpManager.state.supportedBasalRates.indices.contains(1) {
                    let basalRates = pumpManager.state.supportedBasalRates
                    let vc = SupportedRangeTableViewController(minValue: basalRates.first!, maxValue: basalRates.last!, stepSize: basalRates[1] - basalRates.first!)
                    vc.title = "Supported Basal Rates"
                    vc.indexPath = indexPath
                    vc.delegate = self
                    show(vc, sender: sender)
                }
                break
            case .supportedBolusVolumes:
                if pumpManager.state.deliverableIncrements == .custom, pumpManager.state.supportedBolusVolumes.indices.contains(1) {
                    let bolusVolumes = pumpManager.state.supportedBolusVolumes
                    let vc = SupportedRangeTableViewController(minValue: bolusVolumes.first!, maxValue: bolusVolumes.last!, stepSize: bolusVolumes[1] - bolusVolumes.first!)
                    vc.title = "Supported Bolus Volumes"
                    vc.indexPath = indexPath
                    vc.delegate = self
                    show(vc, sender: sender)
                }
                break
            case .insulinType:
                let view = InsulinTypeSetting(initialValue: pumpManager.state.insulinType, supportedInsulinTypes: InsulinType.allCases) { (newType) in
                    self.pumpManager.state.insulinType = newType
                }
                let vc = DismissibleHostingController(rootView: view) {
                    tableView.reloadRows(at: [indexPath], with: .automatic)
                }
                vc.title = LocalizedString("Insulin Type", comment: "Controller title for insulin type selection screen")
                show(vc, sender: sender)
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
            case .tempBasalErrorToggle, .bolusErrorToggle, .bolusCancelErrorToggle, .suspendErrorToggle, .resumeErrorToggle, .uncertainDeliveryErrorToggle:
                break
            case .lastReconciliationDate:
                tableView.deselectRow(at: indexPath, animated: true)
                tableView.beginUpdates()
                tableView.endUpdates()
            }
        case .statusProgress:
            let vc = PercentageTextFieldTableViewController()
            vc.indexPath = indexPath
            vc.percentageDelegate = self
            switch StatusProgressRow(rawValue: indexPath.row)! {
            case .percentComplete:
                vc.percentage = pumpManager.state.progressPercentComplete
            case .warningThreshold:
                vc.percentage = pumpManager.state.progressWarningThresholdPercentValue
            case .criticalThreshold:
                vc.percentage = pumpManager.state.progressCriticalThresholdPercentValue
            }
            show(vc, sender: sender)
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
        default:
            tableView.deselectRow(at: indexPath, animated: true)
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
        default:
            break
        }
    }
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        switch Section(rawValue: indexPath.section)! {
        case .settings:
            switch SettingsRow(rawValue: indexPath.row)! {
            case .lastReconciliationDate:
                
                let resetAction = UIContextualAction(style: .normal, title:  "Reset") {[weak self] _,_,_ in
                    self?.pumpManager.testLastReconciliation = nil
                    tableView.reloadRows(at: [indexPath], with: .automatic)
                }
                resetAction.backgroundColor = .systemRed
                return UISwipeActionsConfiguration(actions: [resetAction])
            default:
                break
            }
        default:
            break
        }
        return nil
    }
    
}

extension MockPumpManagerSettingsViewController: DatePickerTableViewCellDelegate {
    func datePickerTableViewCellDidUpdateDate(_ cell: DatePickerTableViewCell) {
        guard let row = tableView.indexPath(for: cell)?.row else { return }

        switch SettingsRow(rawValue: row) {
        case .lastReconciliationDate?:
            pumpManager.testLastReconciliation = cell.date
        default:
            break
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
        
        tableView.reloadSections([Section.basalRate.rawValue], with: .automatic)
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
            pumpManager.state.reservoirUnitsRemaining = max(value, 0)
        }
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
}

extension MockPumpManagerSettingsViewController: PercentageTextFieldTableViewControllerDelegate {
    func percentageTextFieldTableViewControllerDidChangePercentage(_ controller: PercentageTextFieldTableViewController) {
        guard let indexPath = controller.indexPath else {
            assertionFailure()
            return
        }

        switch indexPath {
        case [Section.settings.rawValue, SettingsRow.batteryRemaining.rawValue]:
            pumpManager.pumpBatteryChargeRemaining = controller.percentage.map { $0.clamped(to: 0...1) }
            tableView.reloadRows(at: [indexPath], with: .automatic)
        case [Section.statusProgress.rawValue, StatusProgressRow.percentComplete.rawValue]:
            pumpManager.state.progressPercentComplete = controller.percentage.map { $0.clamped(to: 0...1) }
            tableView.reloadRows(at: [indexPath], with: .automatic)
        case [Section.statusProgress.rawValue, StatusProgressRow.warningThreshold.rawValue]:
            pumpManager.state.progressWarningThresholdPercentValue = controller.percentage.map { $0.clamped(to: 0...1) }
            tableView.reloadRows(at: [indexPath], with: .automatic)
        case [Section.statusProgress.rawValue, StatusProgressRow.criticalThreshold.rawValue]:
            pumpManager.state.progressCriticalThresholdPercentValue = controller.percentage.map { $0.clamped(to: 0...1) }
            tableView.reloadRows(at: [indexPath], with: .automatic)
        default:
            assertionFailure()
        }
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

extension MockPumpManagerSettingsViewController: SupportedRangeTableViewControllerDelegate {
    func supportedRangeDidUpdate(_ controller: SupportedRangeTableViewController) {
        guard let indexPath = controller.indexPath else {
            assertionFailure()
            return
        }

        let rangeMin = Int(controller.minValue/controller.stepSize)
        let rangeMax = Int(controller.maxValue/controller.stepSize)
        let rangeStep = 1/controller.stepSize
        let values: [Double] = (rangeMin...rangeMax).map { Double($0) / rangeStep }
        
        switch indexPath {
        case [Section.settings.rawValue, SettingsRow.supportedBasalRates.rawValue]:
            pumpManager.state.supportedBasalRates = values
            tableView.reloadRows(at: [indexPath], with: .automatic)
        case [Section.settings.rawValue, SettingsRow.supportedBolusVolumes.rawValue]:
            pumpManager.state.supportedBolusVolumes = values
            tableView.reloadRows(at: [indexPath], with: .automatic)
        default:
            assertionFailure()
        }
    }
}
