//
//  DailyQuantityScheduleTableViewController.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/13/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit
import LoopKit


public class DailyQuantityScheduleTableViewController: SingleValueScheduleTableViewController {

    public var unit: LoopUnit = .gram {
        didSet {
            unitDisplayString = LoopUnit.gramsPerUnit.shortLocalizedUnitString()
        }
    }

    override var preferredValueFractionDigits: Int {
        return unit.preferredFractionDigits
    }

}
