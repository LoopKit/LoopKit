//
//  DailyQuantityScheduleTableViewController.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/13/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit
import HealthKit


public class DailyQuantityScheduleTableViewController: SingleValueScheduleTableViewController {

    public var unit: HKUnit = HKUnit.gram() {
        didSet {
            unitDisplayString = unit.unitDivided(by: .internationalUnit()).shortLocalizedUnitString()
        }
    }

    override var preferredValueFractionDigits: Int {
        return unit.preferredFractionDigits
    }

}
