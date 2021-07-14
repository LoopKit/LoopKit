//
//  RandomOutlierTableViewController.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 11/25/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit
import HealthKit
import LoopKit
import LoopKitUI
import MockKit


protocol RandomOutlierTableViewControllerDelegate: AnyObject {
    func randomOutlierTableViewControllerDidChangeOutlier(_ controller: RandomOutlierTableViewController)
}

final class RandomOutlierTableViewController: UITableViewController {

    let glucoseUnit: HKUnit

    var randomOutlier: MockCGMDataSource.Effects.RandomOutlier? {
        get {
            guard let chance = chance, let delta = delta else {
                return nil
            }
            return (chance: chance, delta: delta)
        }
        set {
            chance = newValue?.chance
            delta = newValue?.delta
        }
    }

    var contextHelp: String?

    var indexPath: IndexPath?

    weak var delegate: RandomOutlierTableViewControllerDelegate?

    private var chance: Double? {
        didSet {
            delegate?.randomOutlierTableViewControllerDidChangeOutlier(self)
        }
    }

    private var delta: HKQuantity? {
        didSet {
            delegate?.randomOutlierTableViewControllerDidChangeOutlier(self)
        }
    }

    private lazy var percentageFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumIntegerDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    private lazy var glucoseFormatter = QuantityFormatter()

    init(glucoseUnit: HKUnit) {
        self.glucoseUnit = glucoseUnit
        super.init(style: .grouped)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(SettingsTableViewCell.self, forCellReuseIdentifier: SettingsTableViewCell.className)
    }

    // MARK: - Data Source

    private enum Row: Int, CaseIterable {
        case chance = 0
        case delta
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Row.allCases.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath) as! SettingsTableViewCell

        switch Row(rawValue: indexPath.row)! {
        case .chance:
            cell.textLabel?.text = "Chance"
            if let chance = chance,
                let percentageText = percentageFormatter.string(from: chance * 100) {
                cell.detailTextLabel?.text = "\(percentageText)%"
            } else {
                cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
            }
        case .delta:
            cell.textLabel?.text = "Delta"
            if let delta = delta {
                cell.detailTextLabel?.text = glucoseFormatter.string(from: delta, for: glucoseUnit)
            } else {
                cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
            }
        }

        cell.accessoryType = .disclosureIndicator
        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let sender = tableView.cellForRow(at: indexPath)

        switch Row(rawValue: indexPath.row)! {
        case .chance:
            let vc = PercentageTextFieldTableViewController()
            vc.percentage = chance
            vc.title = "Chance"
            vc.contextHelp = "The percentage determines the chance with which the CGM will produce an outlier when a glucose value is requested."
            vc.percentageDelegate = self
            show(vc, sender: sender)
        case .delta:
            let vc = GlucoseEntryTableViewController(glucoseUnit: glucoseUnit)
            vc.glucose = delta
            vc.title = "Delta"
            vc.contextHelp = "The delta determines the offset from the expected glucose value when the CGM produces an outlier."
            vc.glucoseEntryDelegate = self
            show(vc, sender: sender)
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return contextHelp
    }
}

extension RandomOutlierTableViewController: PercentageTextFieldTableViewControllerDelegate {
    func percentageTextFieldTableViewControllerDidChangePercentage(_ controller: PercentageTextFieldTableViewController) {
        chance = controller.percentage?.clamped(to: 0...1)
        tableView.reloadRows(at: [[0, Row.chance.rawValue]], with: .automatic)
    }
}

extension RandomOutlierTableViewController: GlucoseEntryTableViewControllerDelegate {
    func glucoseEntryTableViewControllerDidChangeGlucose(_ controller: GlucoseEntryTableViewController) {
        delta = controller.glucose
        tableView.reloadRows(at: [[0, Row.delta.rawValue]], with: .automatic)
    }
}

