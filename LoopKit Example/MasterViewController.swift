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
            return DeviceDataManager.sharedManager
        }
    }

    // MARK: - Data Source

    private enum Section: Int {
        case Data
        case Configuration

        static let count = 2
    }

    private enum DataRow: Int {
        case Carbs = 0
        case Reservoir

        static let count = 2
    }

    private enum ConfigurationRow: Int {
        case BasalRate
        case GlucoseTargetRange

        static let count = 2
    }

    // MARK: UITableViewDataSource

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return Section.count
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .Configuration:
            return ConfigurationRow.count
        case .Data:
            return DataRow.count
        }
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)

        switch Section(rawValue: indexPath.section)! {
        case .Configuration:
            switch ConfigurationRow(rawValue: indexPath.row)! {
            case .BasalRate:
                cell.textLabel?.text = NSLocalizedString("Basal Rates", comment: "The title text for the basal rate schedule")
            case .GlucoseTargetRange:
                cell.textLabel?.text = NSLocalizedString("Glucose Target Range", comment: "The title text for the glucose target range schedule")
            }
        case .Data:
            switch DataRow(rawValue: indexPath.row)! {
            case .Carbs:
                cell.textLabel?.text = NSLocalizedString("Carbs", comment: "The title for the cell navigating to the carbs screen")
            case .Reservoir:
                cell.textLabel?.text = NSLocalizedString("Reservoir", comment: "The title for the cell navigating to the reservoir screen")
            }
        }

        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .Configuration:
            let sender = tableView.cellForRowAtIndexPath(indexPath)
            let row = ConfigurationRow(rawValue: indexPath.row)!
            switch row {
            case .BasalRate:
                let scheduleVC = SingleValueScheduleTableViewController()

                if let profile = dataManager.basalRateSchedule {
                    scheduleVC.timeZone = profile.timeZone
                    scheduleVC.scheduleItems = profile.items
                }
                scheduleVC.delegate = self
                scheduleVC.title = NSLocalizedString("Basal Rates", comment: "The title of the basal rate profile screen")

                showViewController(scheduleVC, sender: sender)
            case .GlucoseTargetRange:
                let scheduleVC = GlucoseRangeScheduleTableViewController()

                scheduleVC.delegate = self
                scheduleVC.title = NSLocalizedString("Target Range", comment: "The title of the glucose target range schedule screen")

                if let schedule = dataManager.glucoseTargetRangeSchedule {
                    scheduleVC.timeZone = schedule.timeZone
                    scheduleVC.scheduleItems = schedule.items
                    scheduleVC.unit = schedule.unit
                    scheduleVC.workoutRange = schedule.workoutRange

                    showViewController(scheduleVC, sender: sender)
                } else if let glucoseStore = dataManager.glucoseStore {
                    glucoseStore.preferredUnit({ (unit, error) -> Void in
                        dispatch_async(dispatch_get_main_queue()) {
                            if let error = error {
                                self.presentAlertControllerWithError(error)
                            } else if let unit = unit {
                                scheduleVC.unit = unit
                                self.showViewController(scheduleVC, sender: sender)
                            }
                        }
                    })
                } else {
                    showViewController(scheduleVC, sender: sender)
                }
            }
        case .Data:
            switch DataRow(rawValue: indexPath.row)! {
            case .Carbs:
                performSegueWithIdentifier(CarbEntryTableViewController.className, sender: indexPath)
            case .Reservoir:
                performSegueWithIdentifier(InsulinDeliveryTableViewController.className, sender: indexPath)
            }
        }
    }

    // MARK: - Segues

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        super.prepareForSegue(segue, sender: sender)

        var targetViewController = segue.destinationViewController

        if let navVC = targetViewController as? UINavigationController, topViewController = navVC.topViewController {
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

    func dailyValueScheduleTableViewControllerWillFinishUpdating(controller: DailyValueScheduleTableViewController) {
        if let indexPath = tableView.indexPathForSelectedRow {
            switch Section(rawValue: indexPath.section)! {
            case .Configuration:
                switch ConfigurationRow(rawValue: indexPath.row)! {
                case .BasalRate:
                    if let controller = controller as? SingleValueScheduleTableViewController {
                        dataManager.basalRateSchedule = BasalRateSchedule(dailyItems: controller.scheduleItems, timeZone: controller.timeZone)
                    }
                case .GlucoseTargetRange:
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
                }

                tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .None)
            default:
                break
            }
        }
    }
}

