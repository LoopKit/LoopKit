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
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "CGM Settings"

        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44

        tableView.register(SettingsTableViewCell.self, forCellReuseIdentifier: SettingsTableViewCell.className)
        tableView.register(TextButtonTableViewCell.self, forCellReuseIdentifier: TextButtonTableViewCell.className)

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
        case effects
        case history
        case deleteCGM
    }

    private enum ModelRow: Int, CaseIterable {
        case constant = 0
        case sineCurve
        case noData
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

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .model:
            return ModelRow.allCases.count
        case .effects:
            return EffectsRow.allCases.count
        case .history:
            return HistoryRow.allCases.count
        case .deleteCGM:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .model:
            return "Model"
        case .effects:
            return "Effects"
        case .history:
            return "History"
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
            }
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
                tableView.reloadRows(at: indexPaths(forSection: .model, rows: ModelRow.self), with: .automatic)
            }
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
        switch indexPath {
        case [Section.model.rawValue, ModelRow.constant.rawValue]:
            if let glucose = controller.glucose {
                cgmManager.dataSource.model = .constant(glucose)
                tableView.reloadRows(at: indexPaths(forSection: .model, rows: ModelRow.self), with: .automatic)
            }
        case [Section.effects.rawValue, EffectsRow.noise.rawValue]:
            if let glucose = controller.glucose {
                cgmManager.dataSource.effects.glucoseNoise = glucose
            }
            tableView.reloadRows(at: [indexPath], with: .automatic)
        default:
            assertionFailure()
        }
    }
}

extension MockCGMManagerSettingsViewController: SineCurveParametersTableViewControllerDelegate {
    func sineCurveParametersTableViewControllerDidUpdateParameters(_ controller: SineCurveParametersTableViewController) {
        if let parameters = controller.parameters {
            cgmManager.dataSource.model = .sineCurve(parameters: parameters)
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

        switch indexPath {
        case [Section.effects.rawValue, EffectsRow.lowOutlier.rawValue]:
            cgmManager.dataSource.effects.randomLowOutlier = controller.randomOutlier
        case [Section.effects.rawValue, EffectsRow.highOutlier.rawValue]:
            cgmManager.dataSource.effects.randomHighOutlier = controller.randomOutlier
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

        switch indexPath {
        case [Section.effects.rawValue, EffectsRow.error.rawValue]:
            if let chance = controller.percentage {
                cgmManager.dataSource.effects.randomErrorChance = chance.clamped(to: 0...100)
            }
            tableView.reloadRows(at: [indexPath], with: .automatic)
        default:
            assertionFailure()
        }
    }
}

extension MockCGMManagerSettingsViewController: GlucoseTrendTableViewControllerDelegate {
    func glucoseTrendTableViewControllerDidChangeTrend(_ controller: GlucoseTrendTableViewController) {
        cgmManager.mockSensorState.trendType = controller.glucoseTrend
        tableView.reloadRows(at: [[Section.history.rawValue, HistoryRow.trend.rawValue]], with: .automatic)
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
