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


class MasterViewController: UITableViewController {

    lazy var carbStore = CarbStore()

    lazy var doseStore = DoseStore(pumpID: nil, insulinActionDuration: nil, basalProfile: nil)

    override func viewWillAppear(animated: Bool) {
        self.clearsSelectionOnViewWillAppear = self.splitViewController!.collapsed
        super.viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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

                carbViewController.carbStore = carbStore
                rootViewController = carbViewController
            case .Reservoir:
                let reservoirViewController = UIStoryboard(name: "InsulinKit", bundle: NSBundle(forClass: ReservoirTableViewController.self)).instantiateInitialViewController() as! ReservoirTableViewController

                reservoirViewController.doseStore = doseStore
                rootViewController = reservoirViewController
            }

            navController.viewControllers = [rootViewController]
            navController.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem()
            navController.navigationItem.leftItemsSupplementBackButton = true
        }
    }

    // MARK: - Table View

    enum Row: Int {
        case Carbs = 0
        case Reservoir

        static let count = 2
    }

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
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
        }

        return cell
    }

}

