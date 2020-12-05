//
//  MockCGMManagerSettingsViewController.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 11/23/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit
import HealthKit
import LoopKit
import LoopKitUI
import MockKit


final class MockCGMManagerSettingsViewController: UITableViewController {
    let cgmManager: MockCGMManager
    let glucoseUnit: HKUnit

    init(cgmManager: MockCGMManager, glucoseUnit: HKUnit) {
        self.cgmManager = cgmManager
        self.glucoseUnit = glucoseUnit
        super.init(style: .grouped)
        title = NSLocalizedString("CGM Settings", comment: "Title for CGM simulator settings")
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44

        tableView.register(SettingsTableViewCell.self, forCellReuseIdentifier: SettingsTableViewCell.className)
        tableView.register(TextButtonTableViewCell.self, forCellReuseIdentifier: TextButtonTableViewCell.className)
        tableView.register(BoundSwitchTableViewCell.self, forCellReuseIdentifier: BoundSwitchTableViewCell.className)

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
        case model = 0
        case glucoseThresholds
        case effects
        case history
        case alerts
        case lifecycleProgress
        case deleteCGM
    }

    private enum ModelRow: Int, CaseIterable {
        case constant = 0
        case sineCurve
        case noData
        case signalLoss
        case frequency
    }
    
    private enum GlucoseThresholds: Int, CaseIterable {
        case enableAlerting
        case cgmLowerLimit
        case urgentLowGlucoseThreshold
        case lowGlucoseThreshold
        case highGlucoseThreshold
        case cgmUpperLimit
    }

    private enum EffectsRow: Int, CaseIterable {
        case noise = 0
        case lowOutlier
        case highOutlier
        case error
    }

    private enum HistoryRow: Int, CaseIterable {
        case trend = 0
        case backfill
    }
    
    private enum AlertsRow: Int, CaseIterable {
        case issueAlert = 0
    }
    
    private enum LifecycleProgressRow: Int, CaseIterable {
        case percentComplete
        case warningThreshold
        case criticalThreshold
    }
        
    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .model:
            return ModelRow.allCases.count
        case .glucoseThresholds:
            return GlucoseThresholds.allCases.count
        case .effects:
            return EffectsRow.allCases.count
        case .history:
            return HistoryRow.allCases.count
        case .alerts:
            return AlertsRow.allCases.count
        case .lifecycleProgress:
            return LifecycleProgressRow.allCases.count
        case .deleteCGM:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .model:
            return "Model"
        case .glucoseThresholds:
            return "Glucose Thresholds"
        case .effects:
            return "Effects"
        case .history:
            return "History"
        case .alerts:
            return "Alerts"
        case .lifecycleProgress:
            return "Lifecycle Progress"
        case .deleteCGM:
            return " " // Use an empty string for more dramatic spacing
        }
    }

    private lazy var quantityFormatter = QuantityFormatter()

    private lazy var percentageFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumIntegerDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .model:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
            switch ModelRow(rawValue: indexPath.row)! {
            case .constant:
                cell.textLabel?.text = "Constant"
                if case .constant(let glucose) = cgmManager.dataSource.model {
                    cell.detailTextLabel?.text = quantityFormatter.string(from: glucose, for: glucoseUnit)
                    cell.accessoryType = .checkmark
                } else {
                    cell.accessoryType = .disclosureIndicator
                }
            case .sineCurve:
                cell.textLabel?.text = "Sine Curve"
                if case .sineCurve(parameters: (baseGlucose: let baseGlucose, amplitude: let amplitude, period: _, referenceDate: _)) = cgmManager.dataSource.model {
                    if let baseGlucoseText = quantityFormatter.numberFormatter.string(from: baseGlucose.doubleValue(for: glucoseUnit)),
                        let amplitudeText = quantityFormatter.string(from: amplitude, for: glucoseUnit) {
                        cell.detailTextLabel?.text = "\(baseGlucoseText) ± \(amplitudeText)"
                    }
                    cell.accessoryType = .checkmark
                } else {
                    cell.accessoryType = .disclosureIndicator
                }
            case .noData:
                cell.textLabel?.text = "No Data"
                if case .noData = cgmManager.dataSource.model {
                    cell.accessoryType = .checkmark
                }
            case .signalLoss:
                cell.textLabel?.text = "Signal Loss"
                if case .signalLoss = cgmManager.dataSource.model {
                    cell.accessoryType = .checkmark
                }
            case .frequency:
                cell.textLabel?.text = "Measurement Frequency"
                cell.detailTextLabel?.text = cgmManager.dataSource.dataPointFrequency.localizedDescription
                cell.accessoryType = .disclosureIndicator
            }
            return cell
        case .glucoseThresholds:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
            switch GlucoseThresholds(rawValue: indexPath.row)! {
            case .enableAlerting:
                let cell = tableView.dequeueReusableCell(withIdentifier: BoundSwitchTableViewCell.className, for: indexPath) as! BoundSwitchTableViewCell
                cell.textLabel?.text = "Glucose Value Alerting"
                cell.switch?.isOn = cgmManager.mockSensorState.glucoseAlertingEnabled
                cell.onToggle = { [unowned cgmManager] isOn in
                    cgmManager.mockSensorState.glucoseAlertingEnabled = isOn
                }
                cell.selectionStyle = .none
                return cell
            case .cgmLowerLimit:
                cell.textLabel?.text = "CGM Lower Limit"
                cell.detailTextLabel?.text = quantityFormatter.string(from: cgmManager.mockSensorState.cgmLowerLimit, for: glucoseUnit)
            case .urgentLowGlucoseThreshold:
                cell.textLabel?.text = "Urgent Low Glucose Threshold"
                cell.detailTextLabel?.text = quantityFormatter.string(from: cgmManager.mockSensorState.urgentLowGlucoseThreshold, for: glucoseUnit)
            case .lowGlucoseThreshold:
                cell.textLabel?.text = "Low Glucose Threshold"
                cell.detailTextLabel?.text = quantityFormatter.string(from: cgmManager.mockSensorState.lowGlucoseThreshold, for: glucoseUnit)
            case .highGlucoseThreshold:
                cell.textLabel?.text = "High Glucose Threshold"
                cell.detailTextLabel?.text = quantityFormatter.string(from: cgmManager.mockSensorState.highGlucoseThreshold, for: glucoseUnit)
            case .cgmUpperLimit:
                cell.textLabel?.text = "CGM Upper Limit"
                cell.detailTextLabel?.text = quantityFormatter.string(from: cgmManager.mockSensorState.cgmUpperLimit, for: glucoseUnit)
            }
            cell.accessoryType = .disclosureIndicator
            return cell
        case .effects:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
            switch EffectsRow(rawValue: indexPath.row)! {
            case .noise:
                cell.textLabel?.text = "Glucose Noise"
                if let maximumDeltaMagnitude = cgmManager.dataSource.effects.glucoseNoise {
                    cell.detailTextLabel?.text = quantityFormatter.string(from: maximumDeltaMagnitude, for: glucoseUnit)
                } else {
                    cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
                }
            case .lowOutlier:
                cell.textLabel?.text = "Random Low Outlier"
                if let chance = cgmManager.dataSource.effects.randomLowOutlier?.chance,
                    let percentageString = percentageFormatter.string(from: chance * 100)
                {
                    cell.detailTextLabel?.text = "\(percentageString)% chance"
                } else {
                    cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
                }
            case .highOutlier:
                cell.textLabel?.text = "Random High Outlier"
                if let chance = cgmManager.dataSource.effects.randomHighOutlier?.chance,
                    let percentageString = percentageFormatter.string(from: chance * 100)
                {
                    cell.detailTextLabel?.text = "\(percentageString)% chance"
                } else {
                    cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
                }
            case .error:
                cell.textLabel?.text = "Random Error"
                if let chance = cgmManager.dataSource.effects.randomErrorChance,
                    let percentageString = percentageFormatter.string(from: chance * 100)
                {
                    cell.detailTextLabel?.text = "\(percentageString)% chance"
                } else {
                    cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
                }
            }

            cell.accessoryType = .disclosureIndicator
            return cell
        case .history:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
            switch HistoryRow(rawValue: indexPath.row)! {
            case .trend:
                cell.textLabel?.text = "Trend"
                cell.detailTextLabel?.text = cgmManager.mockSensorState.trendType?.symbol
            case .backfill:
                cell.textLabel?.text = "Backfill Glucose"
            }
            cell.accessoryType = .disclosureIndicator
            return cell
        case .alerts:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
            switch AlertsRow(rawValue: indexPath.row)! {
            case .issueAlert:
                cell.textLabel?.text = "Issue Alerts"
                cell.accessoryType = .disclosureIndicator
            }
            return cell
        case .lifecycleProgress:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
            switch LifecycleProgressRow(rawValue: indexPath.row)! {
            case .percentComplete:
                cell.textLabel?.text = "Percent Completed"
                if let percentCompleted = cgmManager.mockSensorState.cgmLifecycleProgress?.percentComplete {
                    cell.detailTextLabel?.text = "\(Int(round(percentCompleted * 100)))%"
                } else {
                    cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
                }
            case .warningThreshold:
                cell.textLabel?.text = "Warning Threshold"
                if let warningThreshold = cgmManager.mockSensorState.progressWarningThresholdPercentValue {
                    cell.detailTextLabel?.text = "\(Int(round(warningThreshold * 100)))%"
                } else {
                    cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
                }
            case .criticalThreshold:
                cell.textLabel?.text = "Critical Threshold"
                if let criticalThreshold = cgmManager.mockSensorState.progressCriticalThresholdPercentValue {
                    cell.detailTextLabel?.text = "\(Int(round(criticalThreshold * 100)))%"
                } else {
                    cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
                }
            }
            cell.accessoryType = .disclosureIndicator
            return cell
        case .deleteCGM:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath) as! TextButtonTableViewCell
            cell.textLabel?.text = "Delete CGM"
            cell.textLabel?.textAlignment = .center
            cell.tintColor = .delete
            cell.isEnabled = true
            return cell
        }
    }
    
    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let sender = tableView.cellForRow(at: indexPath)

        switch Section(rawValue: indexPath.section)! {
        case .model:
            switch ModelRow(rawValue: indexPath.row)! {
            case .constant:
                let vc = GlucoseEntryTableViewController(glucoseUnit: glucoseUnit)
                vc.title = "Constant"
                vc.indexPath = indexPath
                vc.contextHelp = "A constant glucose model returns a fixed glucose value regardless of context."
                vc.glucoseEntryDelegate = self
                show(vc, sender: sender)
            case .sineCurve:
                let vc = SineCurveParametersTableViewController(glucoseUnit: glucoseUnit)
                if case .sineCurve(parameters: let parameters) = cgmManager.dataSource.model {
                    vc.parameters = parameters
                } else {
                    vc.parameters = nil
                }
                vc.contextHelp = "The sine curve parameters describe a mathematical model for glucose value production."
                vc.delegate = self
                show(vc, sender: sender)
            case .noData:
                cgmManager.dataSource.model = .noData
                cgmManager.retractSignalLossAlert()
                tableView.reloadRows(at: indexPaths(forSection: .model, rows: ModelRow.self), with: .automatic)
            case .signalLoss:
                cgmManager.dataSource.model = .signalLoss
                cgmManager.issueSignalLossAlert()
                tableView.reloadRows(at: indexPaths(forSection: .model, rows: ModelRow.self), with: .automatic)
            case .frequency:
                let vc = MeasurementFrequencyTableViewController()
                vc.measurementFrequency = cgmManager.dataSource.dataPointFrequency
                vc.title = "Measurement Frequency"
                vc.measurementFrequencyDelegate = self
                show(vc, sender: sender)
            }
        case .glucoseThresholds:
            let vc = GlucoseEntryTableViewController(glucoseUnit: glucoseUnit)
            vc.indexPath = indexPath
            vc.glucoseEntryDelegate = self
            switch GlucoseThresholds(rawValue: indexPath.row)! {
            case .enableAlerting:
                return
            case .cgmLowerLimit:
                vc.title = "CGM Lower Limit"
                vc.contextHelp = "The glucose value that marks the lower limit of the CGM. Any value at or below this value is presented at `LOW`. This value must be lower than the urgent low threshold. If not, it will be set to 1 below the urgent low glucose threshold."
            case .urgentLowGlucoseThreshold:
                vc.title = "Urgent Low Glucose Threshold"
                vc.contextHelp = "The glucose value that marks the urgent low glucose threshold. Any value at or below this value is considered urgent low. This value must be above the cgm lower limit and lower than the low threshold. If not, it will be set to a value above the lower limit and below the low glucose threshold."
            case .lowGlucoseThreshold:
                vc.title = "Low Glucose Threshold"
                vc.contextHelp = "The glucose value that marks the low glucose threshold. Any value at or below this value is considered low. This value must be above the urgent low threshold and lower than the high threshold. If not, it will be set to a value above the urgent lower limit and below the high glucose threshold."
            case .highGlucoseThreshold:
                vc.title = "High Glucose Threshold"
                vc.contextHelp = "The glucose value that marks the high glucose threshold. Any value at or above this value is considered high. This value must be above the low threshold and lower than the cgm upper limit. If not, it will be set to a value above the low glucose threshold and below the upper limit."
            case .cgmUpperLimit:
                vc.title = "CGM Upper Limit"
                vc.contextHelp = "The glucose value that marks the upper limit of the CGM. Any value at or above this value is presented at `HIGH`. This value must be above the high threshold. If not, it will be set to 1 above the high glucose threshold."
            }
            show(vc, sender: sender)
        case .effects:
            switch EffectsRow(rawValue: indexPath.row)! {
            case .noise:
                let vc = GlucoseEntryTableViewController(glucoseUnit: glucoseUnit)
                if let maximumDeltaMagnitude = cgmManager.dataSource.effects.glucoseNoise {
                    vc.glucose = maximumDeltaMagnitude
                }
                vc.title = "Glucose Noise"
                vc.contextHelp = "The magnitude of glucose noise applied to CGM values determines the maximum random amount of variation applied to each glucose value."
                vc.indexPath = indexPath
                vc.glucoseEntryDelegate = self
                show(vc, sender: sender)
            case .lowOutlier:
                let vc = RandomOutlierTableViewController(glucoseUnit: glucoseUnit)
                vc.title = "Low Outlier"
                vc.randomOutlier = cgmManager.dataSource.effects.randomLowOutlier
                vc.contextHelp = "Produced glucose values will have a chance of being decreased by the delta quantity."
                vc.indexPath = indexPath
                vc.delegate = self
                show(vc, sender: sender)
            case .highOutlier:
                let vc = RandomOutlierTableViewController(glucoseUnit: glucoseUnit)
                vc.title = "High Outlier"
                vc.randomOutlier = cgmManager.dataSource.effects.randomHighOutlier
                vc.contextHelp = "Produced glucose values will have a chance of being increased by the delta quantity."
                vc.indexPath = indexPath
                vc.delegate = self
                show(vc, sender: sender)
            case .error:
                let vc = PercentageTextFieldTableViewController()
                if let chance = cgmManager.dataSource.effects.randomErrorChance {
                    vc.percentage = chance
                }
                vc.title = "Random Error"
                vc.contextHelp = "The percentage determines the chance with which the CGM will error when a glucose value is requested."
                vc.indexPath = indexPath
                vc.percentageDelegate = self
                show(vc, sender: sender)
            }
        case .history:
            switch HistoryRow(rawValue: indexPath.row)! {
            case .trend:
                let vc = GlucoseTrendTableViewController()
                vc.glucoseTrend = cgmManager.mockSensorState.trendType
                vc.title = "Glucose Trend"
                vc.glucoseTrendDelegate = self
                show(vc, sender: sender)
            case .backfill:
                let vc = DateAndDurationTableViewController()
                vc.inputMode = .duration(.hours(3))
                vc.title = "Backfill"
                vc.contextHelp = "Performing a backfill will not delete existing prior glucose values."
                vc.indexPath = indexPath
                vc.onSave { inputMode in
                    guard case .duration(let duration) = inputMode else {
                        assertionFailure()
                        return
                    }
                    self.cgmManager.backfillData(datingBack: duration)
                }
                show(vc, sender: sender)
            }
        case .alerts:
            switch AlertsRow(rawValue: indexPath.row)! {
            case .issueAlert:
                let vc = IssueAlertTableViewController(cgmManager: cgmManager)
                show(vc, sender: sender)
            }
        case .lifecycleProgress:
            let vc = PercentageTextFieldTableViewController()
            vc.indexPath = indexPath
            vc.percentageDelegate = self
            switch LifecycleProgressRow(rawValue: indexPath.row)! {
            case .percentComplete:
                vc.percentage = cgmManager.mockSensorState.cgmLifecycleProgress?.percentComplete
            case .warningThreshold:
                vc.percentage = cgmManager.mockSensorState.progressWarningThresholdPercentValue
            case .criticalThreshold:
                vc.percentage = cgmManager.mockSensorState.progressCriticalThresholdPercentValue
            }
            show(vc, sender: sender)
        case .deleteCGM:
            let confirmVC = UIAlertController(cgmDeletionHandler: {
                self.cgmManager.notifyDelegateOfDeletion {
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

    private func indexPaths<Row: CaseIterable & RawRepresentable>(
        forSection section: Section,
        rows _: Row.Type
    ) -> [IndexPath] where Row.RawValue == Int {
        let rows = Row.allCases
        return zip(rows, repeatElement(section, count: rows.count)).map { row, section in
            return IndexPath(row: row.rawValue, section: section.rawValue)
        }
    }
}

extension MockCGMManagerSettingsViewController: GlucoseEntryTableViewControllerDelegate {
    func glucoseEntryTableViewControllerDidChangeGlucose(_ controller: GlucoseEntryTableViewController) {
        guard let indexPath = controller.indexPath else {
            assertionFailure()
            return
        }

        tableView.deselectRow(at: indexPath, animated: true)
        
        switch Section(rawValue: indexPath.section)! {
        case .model:
            switch ModelRow(rawValue: indexPath.row)! {
            case .constant:
                if let glucose = controller.glucose {
                    cgmManager.dataSource.model = .constant(glucose)
                    cgmManager.retractSignalLossAlert()
                    tableView.reloadRows(at: indexPaths(forSection: .model, rows: ModelRow.self), with: .automatic)
                }
            default:
                assertionFailure()
            }
        case .effects:
            switch EffectsRow(rawValue: indexPath.row) {
            case .noise:
                if let glucose = controller.glucose {
                    cgmManager.dataSource.effects.glucoseNoise = glucose
                }
            default:
                assertionFailure()
            }
        case .glucoseThresholds:
            if let glucose = controller.glucose {
                switch GlucoseThresholds(rawValue: indexPath.row)! {
                case .cgmLowerLimit:
                    cgmManager.mockSensorState.cgmLowerLimit = glucose
                case .urgentLowGlucoseThreshold:
                    cgmManager.mockSensorState.urgentLowGlucoseThreshold = glucose
                case .lowGlucoseThreshold:
                    cgmManager.mockSensorState.lowGlucoseThreshold = glucose
                case .highGlucoseThreshold:
                    cgmManager.mockSensorState.highGlucoseThreshold = glucose
                case .cgmUpperLimit:
                    cgmManager.mockSensorState.cgmUpperLimit = glucose
                default:
                    assertionFailure()
                }
            }
        default:
            assertionFailure()
        }
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
}

extension MockCGMManagerSettingsViewController: SineCurveParametersTableViewControllerDelegate {
    func sineCurveParametersTableViewControllerDidUpdateParameters(_ controller: SineCurveParametersTableViewController) {
        if let parameters = controller.parameters {
            cgmManager.dataSource.model = .sineCurve(parameters: parameters)
            cgmManager.retractSignalLossAlert()
            tableView.reloadRows(at: indexPaths(forSection: .model, rows: ModelRow.self), with: .automatic)
        }
    }
}

extension MockCGMManagerSettingsViewController: RandomOutlierTableViewControllerDelegate {
    func randomOutlierTableViewControllerDidChangeOutlier(_ controller: RandomOutlierTableViewController) {
        guard let indexPath = controller.indexPath else {
            assertionFailure()
            return
        }

        switch Section(rawValue: indexPath.section)! {
        case .effects:
            switch EffectsRow(rawValue: indexPath.row)! {
            case .lowOutlier:
                cgmManager.dataSource.effects.randomLowOutlier = controller.randomOutlier
            case .highOutlier:
                cgmManager.dataSource.effects.randomHighOutlier = controller.randomOutlier
            default:
                assertionFailure()
            }
        default:
            assertionFailure()
        }
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
}

extension MockCGMManagerSettingsViewController: PercentageTextFieldTableViewControllerDelegate {
    func percentageTextFieldTableViewControllerDidChangePercentage(_ controller: PercentageTextFieldTableViewController) {
        guard let indexPath = controller.indexPath else {
            assertionFailure()
            return
        }

        switch Section(rawValue: indexPath.section)! {
        case .effects:
            switch EffectsRow(rawValue: indexPath.row)! {
            case .error:
                if let chance = controller.percentage {
                    cgmManager.dataSource.effects.randomErrorChance = chance.clamped(to: 0...100)
                }
            default:
                assertionFailure()
            }
        case .lifecycleProgress:
            switch LifecycleProgressRow(rawValue: indexPath.row)! {
            case .percentComplete:
                if let percentComplete = controller.percentage.map({ $0.clamped(to: 0...1) }) {
                    cgmManager.mockSensorState.cgmLifecycleProgress = MockCGMLifecycleProgress(percentComplete: percentComplete)
                } else {
                    cgmManager.mockSensorState.cgmLifecycleProgress = nil
                }
            case .warningThreshold:
                cgmManager.mockSensorState.progressWarningThresholdPercentValue = controller.percentage.map { $0.clamped(to: 0...1) }
            case .criticalThreshold:
                cgmManager.mockSensorState.progressCriticalThresholdPercentValue = controller.percentage.map { $0.clamped(to: 0...1) }
            }
        default:
            assertionFailure()
        }
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
}

extension MockCGMManagerSettingsViewController: GlucoseTrendTableViewControllerDelegate {
    func glucoseTrendTableViewControllerDidChangeTrend(_ controller: GlucoseTrendTableViewController) {
        cgmManager.mockSensorState.trendType = controller.glucoseTrend
        tableView.reloadRows(at: [[Section.history.rawValue, HistoryRow.trend.rawValue]], with: .automatic)
    }
}

extension MockCGMManagerSettingsViewController: MeasurementFrequencyTableViewControllerDelegate {
    func measurementFrequencyTableViewControllerDidChangeFrequency(_ controller: MeasurementFrequencyTableViewController) {
        if let measurementFrequency = controller.measurementFrequency {
            cgmManager.dataSource.dataPointFrequency = measurementFrequency
            cgmManager.updateGlucoseUpdateTimer()
            tableView.reloadRows(at: [[Section.model.rawValue, ModelRow.frequency.rawValue]], with: .automatic)
        }
    }
}

private extension UIAlertController {
    convenience init(cgmDeletionHandler handler: @escaping () -> Void) {
        self.init(
            title: nil,
            message: "Are you sure you want to delete this CGM?",
            preferredStyle: .actionSheet
        )

        addAction(UIAlertAction(
            title: "Delete CGM",
            style: .destructive,
            handler: { _ in
                handler()
            }
        ))

        let cancel = "Cancel"
        addAction(UIAlertAction(title: cancel, style: .cancel, handler: nil))
    }
}
