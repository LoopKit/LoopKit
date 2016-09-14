//
//  MasterViewController.swift
//  LoopKit Example
//
//  Created by Nathan Racklyeft on 2/24/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit
import CarbKit
import LoopKit
import InsulinKit


class MasterViewController: UITableViewController, DailyValueScheduleTableViewControllerDelegate {

    private var dataManager: DeviceDataManager {
        get {
            return DeviceDataManager.shared
        }
    }

    // MARK: - Data Source

    private enum Section: Int {
        case data
        case configuration

        static let count = 2
    }

    private enum DataRow: Int {
        case carbs = 0
        case reservoir

        static let count = 2
    }

    private enum ConfigurationRow: Int {
        case basalRate
        case glucoseTargetRange
        case pumpID

        static let count = 3
    }

    // MARK: UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .configuration:
            return ConfigurationRow.count
        case .data:
            return DataRow.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        switch Section(rawValue: indexPath.section)! {
        case .configuration:
            switch ConfigurationRow(rawValue: indexPath.row)! {
            case .basalRate:
                cell.textLabel?.text = NSLocalizedString("Basal Rates", comment: "The title text for the basal rate schedule")
            case .glucoseTargetRange:
                cell.textLabel?.text = NSLocalizedString("Glucose Target Range", comment: "The title text for the glucose target range schedule")
            case .pumpID:
                cell.textLabel?.text = NSLocalizedString("Pump ID", comment: "The title text for the pump ID")
            }
        case .data:
            switch DataRow(rawValue: indexPath.row)! {
            case .carbs:
                cell.textLabel?.text = NSLocalizedString("Carbs", comment: "The title for the cell navigating to the carbs screen")
            case .reservoir:
                cell.textLabel?.text = NSLocalizedString("Reservoir", comment: "The title for the cell navigating to the reservoir screen")
            }
        }

        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .configuration:
            let sender = tableView.cellForRow(at: indexPath)
            let row = ConfigurationRow(rawValue: indexPath.row)!
            switch row {
            case .basalRate:
                let scheduleVC = SingleValueScheduleTableViewController()

                if let profile = dataManager.basalRateSchedule {
                    scheduleVC.timeZone = profile.timeZone
                    scheduleVC.scheduleItems = profile.items
                }
                scheduleVC.delegate = self
                scheduleVC.title = sender?.textLabel?.text

                show(scheduleVC, sender: sender)
            case .glucoseTargetRange:
                let scheduleVC = GlucoseRangeScheduleTableViewController()

                scheduleVC.delegate = self
                scheduleVC.title = sender?.textLabel?.text

                if let schedule = dataManager.glucoseTargetRangeSchedule {
                    scheduleVC.timeZone = schedule.timeZone
                    scheduleVC.scheduleItems = schedule.items
                    scheduleVC.unit = schedule.unit
                    scheduleVC.workoutRange = schedule.workoutRange

                    show(scheduleVC, sender: sender)
                } else if let glucoseStore = dataManager.glucoseStore {
                    glucoseStore.preferredUnit({ (unit, error) -> Void in
                        DispatchQueue.main.async {
                            if let error = error {
                                self.presentAlertController(with: error)
                            } else if let unit = unit {
                                scheduleVC.unit = unit
                                self.show(scheduleVC, sender: sender)
                            }
                        }
                    })
                } else {
                    show(scheduleVC, sender: sender)
                }
            case .pumpID:
                let textFieldVC = TextFieldTableViewController()

//                textFieldVC.delegate = self
                textFieldVC.title = sender?.textLabel?.text
                textFieldVC.placeholder = NSLocalizedString("Enter the 6-digit pump ID", comment: "The placeholder text instructing users how to enter a pump ID")
                textFieldVC.value = dataManager.pumpID
                textFieldVC.keyboardType = .numberPad
                textFieldVC.contextHelp = NSLocalizedString("The pump ID can be found printed on the back, or near the bottom of the STATUS/Esc screen. It is the strictly numerical portion of the serial number (shown as SN or S/N).", comment: "Instructions on where to find the pump ID on a Minimed pump")

                show(textFieldVC, sender: sender)
            }
        case .data:
            switch DataRow(rawValue: indexPath.row)! {
            case .carbs:
                performSegue(withIdentifier: CarbEntryTableViewController.className, sender: indexPath)
            case .reservoir:
                performSegue(withIdentifier: InsulinDeliveryTableViewController.className, sender: indexPath)
            }
        }
    }

    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        var targetViewController = segue.destination

        if let navVC = targetViewController as? UINavigationController, let topViewController = navVC.topViewController {
            targetViewController = topViewController
        }

        switch targetViewController {
        case let vc as CarbEntryTableViewController:
            vc.carbStore = dataManager.carbStore
        case let vc as CarbEntryEditViewController:
            if let carbStore = dataManager.carbStore {
                vc.defaultAbsorptionTimes = carbStore.defaultAbsorptionTimes
                vc.preferredUnit = carbStore.preferredUnit
            }
        case let vc as InsulinDeliveryTableViewController:
            vc.doseStore = dataManager.doseStore
        default:
            break
        }
    }

    // MARK: - DailyValueScheduleTableViewControllerDelegate

    func dailyValueScheduleTableViewControllerWillFinishUpdating(_ controller: DailyValueScheduleTableViewController) {
        if let indexPath = tableView.indexPathForSelectedRow {
            switch Section(rawValue: indexPath.section)! {
            case .configuration:
                switch ConfigurationRow(rawValue: indexPath.row)! {
                case .basalRate:
                    if let controller = controller as? SingleValueScheduleTableViewController {
                        dataManager.basalRateSchedule = BasalRateSchedule(dailyItems: controller.scheduleItems, timeZone: controller.timeZone)
                    }
                case .glucoseTargetRange:
                    if let controller = controller as? GlucoseRangeScheduleTableViewController {
                        dataManager.glucoseTargetRangeSchedule = GlucoseRangeSchedule(unit: controller.unit, dailyItems: controller.scheduleItems, workoutRange: controller.workoutRange, timeZone: controller.timeZone)
                    }
                /*case let row:
                    if let controller = controller as? DailyQuantityScheduleTableViewController {
                        switch row {
                        case .CarbRatio:
                            dataManager.carbRatioSchedule = CarbRatioSchedule(unit: controller.unit, dailyItems: controller.scheduleItems, timeZone: controller.timeZone)
                        case .InsulinSensitivity:
                            dataManager.insulinSensitivitySchedule = InsulinSensitivitySchedule(unit: controller.unit, dailyItems: controller.scheduleItems, timeZone: controller.timeZone)
                        default:
                            break
                        }
                    }*/
                default:
                    break
                }

                tableView.reloadRows(at: [indexPath], with: .none)
            default:
                break
            }
        }
    }
}

