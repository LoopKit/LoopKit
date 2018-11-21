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


final class MockCGMManagerSettingsViewController: UITableViewController {
    let cgmManager: MockCGMManager
    let glucoseUnit: HKUnit

    private var model: MockCGMDataSource.Model {
        didSet {
            cgmManager.dataSource = MockCGMDataSource(model: model, effects: effects)
        }
    }

    private var effects: MockCGMDataSource.Effects {
        didSet {
            cgmManager.dataSource = MockCGMDataSource(model: model, effects: effects)
        }
    }

    init(cgmManager: MockCGMManager, glucoseUnit: HKUnit) {
        self.cgmManager = cgmManager
        self.glucoseUnit = glucoseUnit
        self.model = cgmManager.dataSource.model
        self.effects = cgmManager.dataSource.effects
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
    }

    // MARK: - Data Source

    private enum Section: Int, CaseIterable {
        // TODO: trend config?
        case model = 0
        case effects
        case deleteHealthData
        case deleteCGM
    }

    private enum ModelRow: Int, CaseIterable {
        case constant = 0
        case sineCurve
        case noData
    }

    private enum EffectsRow: Int, CaseIterable {
        case delay = 0
        case noise
        case lowOutlier
        case highOutlier
        case error
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
        case .deleteHealthData, .deleteCGM:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .model:
            return "Model"
        case .effects:
            return "Effects"
        case .deleteHealthData, .deleteCGM:
            return " " // Use an empty string for more dramatic spacing
        }
    }

    private lazy var durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute]
        formatter.unitsStyle = .brief
        return formatter
    }()

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
                if case .constant(let glucose) = model {
                    cell.detailTextLabel?.text = quantityFormatter.string(from: glucose, for: glucoseUnit)
                    cell.accessoryType = .checkmark
                } else {
                    cell.accessoryType = .disclosureIndicator
                }
            case .sineCurve:
                cell.textLabel?.text = "Sine Curve"
                if case .sineCurve(parameters: (baseGlucose: let baseGlucose, amplitude: let amplitude, period: _, referenceDate: _)) = model {
                    if let baseGlucoseText = quantityFormatter.string(from: baseGlucose, for: glucoseUnit),
                        let amplitudeText = quantityFormatter.string(from: amplitude, for: glucoseUnit) {
                        cell.detailTextLabel?.text = "\(baseGlucoseText) ± \(amplitudeText)"
                    }
                    cell.accessoryType = .checkmark
                } else {
                    cell.accessoryType = .disclosureIndicator
                }
            case .noData:
                cell.textLabel?.text = "No Data"
                if case .noData = model {
                    cell.accessoryType = .checkmark
                }
            }
            return cell
        case .effects:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
            switch EffectsRow(rawValue: indexPath.row)! {
            case .delay:
                cell.textLabel?.text = "Data Delay"
                if let delay = effects.delay {
                    cell.detailTextLabel?.text = durationFormatter.string(from: delay)
                } else {
                    cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
                }
            case .noise:
                cell.textLabel?.text = "Glucose Noise"
                if let maximumDeltaMagnitude = effects.glucoseNoise {
                    cell.detailTextLabel?.text = quantityFormatter.string(from: maximumDeltaMagnitude, for: glucoseUnit)
                } else {
                    cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
                }
            case .lowOutlier:
                cell.textLabel?.text = "Random Low Outlier"
                if let (chance: chance, delta: delta) = effects.randomLowOutlier,
                    let percentageString = percentageFormatter.string(from: chance),
                    let quantityString = quantityFormatter.string(from: delta, for: glucoseUnit)
                {
                    cell.detailTextLabel?.text = "\(percentageString)% chance of -\(quantityString)"
                } else {
                    cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
                }
            case .highOutlier:
                cell.textLabel?.text = "Random High Outlier"
                if let (chance: chance, delta: delta) = effects.randomHighOutlier,
                    let percentageString = percentageFormatter.string(from: chance),
                    let quantityString = quantityFormatter.string(from: delta, for: glucoseUnit)
                {
                    cell.detailTextLabel?.text = "\(percentageString)% chance of +\(quantityString)"
                } else {
                    cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
                }
            case .error:
                cell.textLabel?.text = "Random Error"
                if let chance = effects.randomErrorChance,
                    let percentageString = percentageFormatter.string(from: chance)
                {
                    cell.detailTextLabel?.text = "\(percentageString)% chance"
                } else {
                    cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
                }
            }

            cell.accessoryType = .disclosureIndicator
            return cell
        case .deleteHealthData:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath) as! TextButtonTableViewCell
            cell.textLabel?.text = "Delete Health Data"
            cell.textLabel?.textAlignment = .center
            cell.tintColor = .delete
            cell.isEnabled = true
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
                if case .sineCurve(parameters: let parameters) = model {
                    vc.parameters = parameters
                }
                vc.delegate = self
                show(vc, sender: sender)
            case .noData:
                model = .noData
                tableView.reloadRows(at: indexPaths(forSection: .model, rows: ModelRow.self), with: .automatic)
            }
        case .effects:
            switch EffectsRow(rawValue: indexPath.row)! {
            case .delay:
                let vc = DateAndDurationTableViewController()
                vc.inputMode = .duration(effects.delay ?? .minutes(1)) // sensible default
                vc.title = "Data Delay"
                vc.contextHelp = "The delay applies to the time after a CGM value is requested."
                vc.indexPath = indexPath
                show(vc, sender: sender)
            case .noise:
                let vc = GlucoseEntryTableViewController(glucoseUnit: glucoseUnit)
                if let maximumDeltaMagnitude = effects.glucoseNoise {
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
                vc.randomOutlier = effects.randomLowOutlier
                vc.indexPath = indexPath
                vc.delegate = self
                show(vc, sender: sender)
            case .highOutlier:
                let vc = RandomOutlierTableViewController(glucoseUnit: glucoseUnit)
                vc.title = "High Outlier"
                vc.randomOutlier = effects.randomHighOutlier
                vc.indexPath = indexPath
                vc.delegate = self
                show(vc, sender: sender)
            case .error:
                let vc = PercentageTextFieldTableViewController()
                if let chance = effects.randomErrorChance {
                    vc.percentage = chance
                }
                vc.title = "Random Error"
                vc.contextHelp = "The percentage determines the chance with which the CGM will error when a glucose value is requested."
                vc.indexPath = indexPath
                vc.percentageDelegate = self
                show(vc, sender: sender)
            }
        case .deleteHealthData:
            let confirmVC = UIAlertController(healthDataDeletionHandler: {
                self.cgmManager.deleteCGMData()
            })

            present(confirmVC, animated: true) {
                tableView.deselectRow(at: indexPath, animated: true)
            }
        case .deleteCGM:
            let confirmVC = UIAlertController(cgmDeletionHandler: {
                self.cgmManager.cgmManagerDelegate?.cgmManagerWantsDeletion(self.cgmManager)
                self.navigationController?.popViewController(animated: true)
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
        return zip(rows, repeatElement(section, count: rows.count))
            .map { row, section in IndexPath(row: row.rawValue, section: section.rawValue) }
    }
}

extension MockCGMManagerSettingsViewController: DateAndDurationTableViewControllerDelegate {
    func dateAndDurationTableViewControllerDidChangeDate(_ controller: DateAndDurationTableViewController) {
        guard let indexPath = controller.indexPath else {
            assertionFailure()
            return
        }

        assert(indexPath == [Section.effects.rawValue, EffectsRow.delay.rawValue])
        guard case .duration(let duration) = controller.inputMode else {
            assertionFailure()
            return
        }
        // TODO: how to describe no delay?
        effects.delay = duration
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
                model = .constant(glucose)
                tableView.reloadRows(at: indexPaths(forSection: .model, rows: ModelRow.self), with: .automatic)
            }
        case [Section.effects.rawValue, EffectsRow.noise.rawValue]:
            if let glucose = controller.glucose {
                effects.glucoseNoise = glucose
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
            model = .sineCurve(parameters: parameters)
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
            effects.randomLowOutlier = controller.randomOutlier
        case [Section.effects.rawValue, EffectsRow.highOutlier.rawValue]:
            effects.randomHighOutlier = controller.randomOutlier
        default:
            assertionFailure()
        }
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
                effects.randomErrorChance = chance.clamped(to: 0...100)
            }
            tableView.reloadRows(at: [indexPath], with: .automatic)
        default:
            assertionFailure()
        }
    }
}

private extension UIAlertController {
    convenience init(healthDataDeletionHandler handler: @escaping () -> Void) {
        self.init(
            title: nil,
            message: "Are you sure you want to delete mock CGM health data?",
            preferredStyle: .actionSheet
        )

        addAction(UIAlertAction(
            title: "Delete Health Data",
            style: .destructive,
            handler: { _ in handler() }
        ))

        addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    }

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
