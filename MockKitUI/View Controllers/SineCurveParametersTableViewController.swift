//
//  SineCurveParametersTableViewController.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 11/24/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit
import HealthKit
import LoopKit
import LoopKitUI
import MockKit


protocol SineCurveParametersTableViewControllerDelegate: AnyObject {
    func sineCurveParametersTableViewControllerDidUpdateParameters(_ controller: SineCurveParametersTableViewController)
}

final class SineCurveParametersTableViewController: UITableViewController {

    let glucoseUnit: HKUnit

    var parameters: MockCGMDataSource.Model.SineCurveParameters? {
        get {
            if let baseGlucose = baseGlucose,
                let amplitude = amplitude,
                let period = period,
                let referenceDate = referenceDate
            {
                return (baseGlucose: baseGlucose, amplitude: amplitude, period: period, referenceDate: referenceDate)
            } else {
                return nil
            }
        }
        set {
            baseGlucose = newValue?.baseGlucose
            amplitude = newValue?.amplitude
            period = newValue?.period ?? defaultPeriod
            referenceDate = newValue?.referenceDate ?? defaultReferenceDate
        }
    }

    var defaultPeriod: TimeInterval = .hours(6)
    var defaultReferenceDate = Date()

    private var baseGlucose: HKQuantity? {
        didSet {
            delegate?.sineCurveParametersTableViewControllerDidUpdateParameters(self)
        }
    }

    private var amplitude: HKQuantity? {
        didSet {
            delegate?.sineCurveParametersTableViewControllerDidUpdateParameters(self)
        }
    }

    private var period: TimeInterval? {
        didSet {
            delegate?.sineCurveParametersTableViewControllerDidUpdateParameters(self)
        }
    }

    private var referenceDate: Date? {
        didSet {
            delegate?.sineCurveParametersTableViewControllerDidUpdateParameters(self)
        }
    }

    var contextHelp: String?

    weak var delegate: SineCurveParametersTableViewControllerDelegate?

    private lazy var glucoseFormatter = QuantityFormatter()

    private lazy var durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        return formatter
    }()

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    init(glucoseUnit: HKUnit) {
        self.glucoseUnit = glucoseUnit
        super.init(style: .grouped)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Sine Curve"

        tableView.register(SettingsTableViewCell.self, forCellReuseIdentifier: SettingsTableViewCell.className)
    }

    // MARK: - Data Source

    private enum Row: Int, CaseIterable {
        case baseGlucose = 0
        case amplitude
        case period
        case referenceDate
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Row.allCases.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath) as! SettingsTableViewCell
        let formatGlucose = { self.glucoseFormatter.string(from: $0, for: self.glucoseUnit) }

        switch Row(rawValue: indexPath.row)! {
        case .baseGlucose:
            cell.textLabel?.text = "Base Glucose"
            cell.detailTextLabel?.text = baseGlucose.map(formatGlucose) ?? SettingsTableViewCell.NoValueString
        case .amplitude:
            cell.textLabel?.text = "Amplitude"
            cell.detailTextLabel?.text = amplitude.map(formatGlucose) ?? SettingsTableViewCell.NoValueString
        case .period:
            cell.textLabel?.text = "Period"
            cell.detailTextLabel?.text = period.flatMap(durationFormatter.string(from:)) ?? SettingsTableViewCell.NoValueString
        case .referenceDate:
            cell.textLabel?.text = "Reference Date"
            cell.detailTextLabel?.text = referenceDate.map(dateFormatter.string(from:)) ?? SettingsTableViewCell.NoValueString
        }

        cell.accessoryType = .disclosureIndicator
        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let sender = tableView.cellForRow(at: indexPath)
        let title = sender?.textLabel?.text

        func presentGlucoseEntryViewController(for glucose: HKQuantity?, contextHelp: String?) {
            let vc = GlucoseEntryTableViewController(glucoseUnit: glucoseUnit)
            vc.glucose = glucose
            vc.title = title
            vc.contextHelp = contextHelp
            vc.indexPath = indexPath
            vc.glucoseEntryDelegate = self
            show(vc, sender: sender)
        }

        func presentDateAndDurationViewController(for inputMode: DateAndDurationTableViewController.InputMode, contextHelp: String?) {
            let vc = DateAndDurationTableViewController()
            vc.inputMode = inputMode
            vc.title = title
            vc.contextHelp = contextHelp
            vc.indexPath = indexPath
            vc.delegate = self
            show(vc, sender: sender)
        }

        switch Row(rawValue: indexPath.row)! {
        case .baseGlucose:
            presentGlucoseEntryViewController(for: baseGlucose, contextHelp: "The base glucose represents the zero about which the sine curve oscillates.")
        case .amplitude:
            presentGlucoseEntryViewController(for: amplitude, contextHelp: "The amplitude represents the magnitude of the oscillation of the glucose curve.")
        case .period:
            presentDateAndDurationViewController(for: .duration(period ?? defaultPeriod), contextHelp: "The period describes the duration of one complete glucose cycle.")
        case .referenceDate:
            presentDateAndDurationViewController(for: .date(referenceDate ?? defaultReferenceDate, mode: .dateAndTime), contextHelp: "The reference date describes the origin of the sine curve with respect to time. Changing the reference date applies a phase shift to the curve.")
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return contextHelp
    }
}

extension SineCurveParametersTableViewController: GlucoseEntryTableViewControllerDelegate {
    func glucoseEntryTableViewControllerDidChangeGlucose(_ controller: GlucoseEntryTableViewController) {
        guard let indexPath = controller.indexPath else {
            assertionFailure()
            return
        }

        switch Row(rawValue: indexPath.row)! {
        case .baseGlucose:
            baseGlucose = controller.glucose
        case .amplitude:
            amplitude = controller.glucose
        default:
            assertionFailure()
        }

        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
}

extension SineCurveParametersTableViewController: DateAndDurationTableViewControllerDelegate {
    func dateAndDurationTableViewControllerDidChangeDate(_ controller: DateAndDurationTableViewController) {
        guard let indexPath = controller.indexPath else {
            assertionFailure()
            return
        }

        switch Row(rawValue: indexPath.row)! {
        case .period:
            guard case .duration(let duration) = controller.inputMode else {
                assertionFailure()
                return
            }
            period = duration
        case .referenceDate:
            guard case .date(let date, mode: _) = controller.inputMode else {
                assertionFailure()
                return
            }
            referenceDate = date
        default:
            assertionFailure()
        }

        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
}
