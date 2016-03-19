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

    override func viewWillAppear(animated: Bool) {
        self.clearsSelectionOnViewWillAppear = self.splitViewController!.collapsed
        super.viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    private var dataManager: DeviceDataManager {
        get {
            return DeviceDataManager.sharedManager
        }
    }

    // MARK: - Segues

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showDetail", let
            indexPath = self.tableView.indexPathForSelectedRow,
            navController = segue.destinationViewController as? UINavigationController
        {
            let rootViewController: UIViewController

            switch Row(rawValue: indexPath.row)! {
            case .Carbs:
                let carbViewController = UIStoryboard(name: "CarbKit", bundle: NSBundle(forClass: CarbEntryTableViewController.self)).instantiateInitialViewController() as! CarbEntryTableViewController

                carbViewController.carbStore = dataManager.carbStore
                rootViewController = carbViewController
            case .Reservoir:
                let reservoirViewController = UIStoryboard(name: "InsulinKit", bundle: NSBundle(forClass: ReservoirTableViewController.self)).instantiateInitialViewController() as! ReservoirTableViewController

                reservoirViewController.doseStore = dataManager.doseStore
                rootViewController = reservoirViewController
            case .BasalRates:
                let scheduleVC = SingleValueScheduleTableViewController()

                scheduleVC.title = NSLocalizedString("Basal Rates", comment: "The title of the basal rate profile screen")

                if let basalRates = dataManager.basalRateSchedule {
                    scheduleVC.scheduleItems = basalRates.items
                    scheduleVC.timeZone = basalRates.timeZone
                }

                scheduleVC.delegate = self

                rootViewController = scheduleVC
            }

            navController.viewControllers = [rootViewController]
            navController.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem()
            navController.navigationItem.leftItemsSupplementBackButton = true
        }
    }

    // MARK: - Table View

    enum Section: Int {
        case First

        static let count = 1
    }

    enum Row: Int {
        case Carbs = 0
        case Reservoir
        case BasalRates

        static let count = 3
    }

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return Section.count
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Row.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)

        switch Row(rawValue: indexPath.row)! {
        case .Carbs:
            cell.textLabel?.text = NSLocalizedString("Carbs", comment: "The title for the cell navigating to the carbs screen")
        case .Reservoir:
            cell.textLabel?.text = NSLocalizedString("Reservoir", comment: "The title for the cell navigating to the reservoir screen")
        case .BasalRates:
            cell.textLabel?.text = NSLocalizedString("Basal Rates", comment: "The title text for the basal rate schedule")
        }

        return cell
    }

    // MARK: - DailyValueScheduleTableViewControllerDelegate

    func dailyValueScheduleTableViewControllerWillFinishUpdating(controller: DailyValueScheduleTableViewController) {
        if let indexPath = tableView.indexPathForSelectedRow {
            switch Section(rawValue: indexPath.section)! {
            case .First:
                switch Row(rawValue: indexPath.row)! {
                case .BasalRates:
                    if let controller = controller as? SingleValueScheduleTableViewController {
                        dataManager.basalRateSchedule = BasalRateSchedule(dailyItems: controller.scheduleItems, timeZone: controller.timeZone)
                    }
//                case .GlucoseTargetRange:
//                    if let controller = controller as? GlucoseRangeScheduleTableViewController {
//                        dataManager.glucoseTargetRangeSchedule = GlucoseRangeSchedule(unit: controller.unit, dailyItems: controller.scheduleItems, timeZone: controller.timeZone)
//                    }
                case _:
                    break
//                    if let controller = controller as? DailyQuantityScheduleTableViewController {
//                        switch section {
//                        case .CarbRatio:
//                            dataManager.carbRatioSchedule = CarbRatioSchedule(unit: controller.unit, dailyItems: controller.scheduleItems, timeZone: controller.timeZone)
//                        case .InsulinSensitivity:
//                            dataManager.insulinSensitivitySchedule = InsulinSensitivitySchedule(unit: controller.unit, dailyItems: controller.scheduleItems, timeZone: controller.timeZone)
//                        default:
//                            break
//                        }
//                    }
                }

                tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .None)
            }
        }
    }
}

