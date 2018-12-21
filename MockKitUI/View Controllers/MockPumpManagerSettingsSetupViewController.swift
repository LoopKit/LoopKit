//
//  MockPumpManagerSettingsSetupViewController.swift
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


final class MockPumpManagerSettingsSetupViewController: SetupTableViewController {

    var pumpManager: MockPumpManager?

    private var pumpManagerSetupViewController: MockPumpManagerSetupViewController? {
        return setupViewController as? MockPumpManagerSetupViewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(SettingsTableViewCell.self, forCellReuseIdentifier: SettingsTableViewCell.className)
    }

    private lazy var quantityFormatter: QuantityFormatter = {
        let quantityFormatter = QuantityFormatter()
        quantityFormatter.numberFormatter.minimumFractionDigits = 0
        quantityFormatter.numberFormatter.maximumFractionDigits = 3

        return quantityFormatter
    }()

    // MARK: - Table view data source

    private enum Section: Int, CaseIterable {
        case configuration
    }

    private enum ConfigurationRow: Int, CaseIterable {
        case basalRates
        case deliveryLimits
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .configuration:
            return ConfigurationRow.allCases.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .configuration:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)

            switch ConfigurationRow(rawValue: indexPath.row)! {
            case .basalRates:
                cell.textLabel?.text = "Basal Rates"

                if let basalRateSchedule = setupViewController?.basalSchedule {
                    let unit = HKUnit.internationalUnit()
                    let total = HKQuantity(unit: unit, doubleValue: basalRateSchedule.total())
                    cell.detailTextLabel?.text = quantityFormatter.string(from: total, for: unit)
                } else {
                    cell.detailTextLabel?.text = SettingsTableViewCell.TapToSetString
                }
            case .deliveryLimits:
                cell.textLabel?.text = "Delivery Limits"

                if setupViewController?.maxBolusUnits == nil || setupViewController?.maxBasalRateUnitsPerHour == nil {
                    cell.detailTextLabel?.text = SettingsTableViewCell.TapToSetString
                } else {
                    cell.detailTextLabel?.text = SettingsTableViewCell.EnabledString
                }
            }

            cell.accessoryType = .disclosureIndicator

            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let sender = tableView.cellForRow(at: indexPath)

        switch Section(rawValue: indexPath.section)! {
        case .configuration:
            switch ConfigurationRow(rawValue: indexPath.row)! {
            case .basalRates:
                let vc = SingleValueScheduleTableViewController(style: .grouped)

                if let profile = setupViewController?.basalSchedule {
                    vc.scheduleItems = profile.items
                    vc.timeZone = profile.timeZone
                }

                vc.title = sender?.textLabel?.text
                vc.delegate = self
                vc.syncSource = pumpManager

                show(vc, sender: sender)
            case .deliveryLimits:
                let vc = DeliveryLimitSettingsTableViewController(style: .grouped)

                vc.maximumBasalRatePerHour = setupViewController?.maxBasalRateUnitsPerHour
                vc.maximumBolus = setupViewController?.maxBolusUnits

                vc.title = sender?.textLabel?.text
                vc.delegate = self
                vc.syncSource = pumpManager

                show(vc, sender: sender)
            }
        }
    }

    override func continueButtonPressed(_ sender: Any) {
        if let setupViewController = setupViewController as? MockPumpManagerSetupViewController {
            setupViewController.completeSetup()
        }
    }
}

extension MockPumpManagerSettingsSetupViewController: DailyValueScheduleTableViewControllerDelegate {
    func dailyValueScheduleTableViewControllerWillFinishUpdating(_ controller: DailyValueScheduleTableViewController) {
        if let controller = controller as? SingleValueScheduleTableViewController {
            pumpManagerSetupViewController?.basalSchedule = BasalRateSchedule(dailyItems: controller.scheduleItems, timeZone: controller.timeZone)
        }

        tableView.reloadRows(at: [[Section.configuration.rawValue, ConfigurationRow.basalRates.rawValue]], with: .none)
    }
}

extension MockPumpManagerSettingsSetupViewController: DeliveryLimitSettingsTableViewControllerDelegate {
    func deliveryLimitSettingsTableViewControllerDidUpdateMaximumBasalRatePerHour(_ vc: DeliveryLimitSettingsTableViewController) {
        pumpManagerSetupViewController?.maxBasalRateUnitsPerHour = vc.maximumBasalRatePerHour

        tableView.reloadRows(at: [[Section.configuration.rawValue, ConfigurationRow.deliveryLimits.rawValue]], with: .none)
    }

    func deliveryLimitSettingsTableViewControllerDidUpdateMaximumBolus(_ vc: DeliveryLimitSettingsTableViewController) {
        pumpManagerSetupViewController?.maxBolusUnits = vc.maximumBolus

        tableView.reloadRows(at: [[Section.configuration.rawValue, ConfigurationRow.deliveryLimits.rawValue]], with: .none)
    }
}
