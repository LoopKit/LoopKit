//
//  GlucoseEntryTableViewController.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 11/24/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit
import HealthKit
import LoopKit


protocol GlucoseEntryTableViewControllerDelegate: class {
    func glucoseEntryTableViewControllerDidChangeGlucose(_ controller: GlucoseEntryTableViewController)
}

class GlucoseEntryTableViewController: TextFieldTableViewController {

    let glucoseUnit: HKUnit

    private lazy var glucoseFormatter: NumberFormatter = {
        let quantityFormatter = QuantityFormatter()
        quantityFormatter.setPreferredNumberFormatter(for: glucoseUnit)
        return quantityFormatter.numberFormatter
    }()

    var glucose: HKQuantity? {
        get {
            guard let doubleValue = value.flatMap(Double.init) else {
                return nil
            }
            return HKQuantity(unit: glucoseUnit, doubleValue: doubleValue)
        }
        set {
            if let newValue = newValue {
                value = glucoseFormatter.string(from: newValue.doubleValue(for: glucoseUnit))
            } else {
                value = nil
            }
        }
    }

    weak var glucoseEntryDelegate: GlucoseEntryTableViewControllerDelegate?

    init(glucoseUnit: HKUnit) {
        self.glucoseUnit = glucoseUnit
        super.init(style: .grouped)
        unit = glucoseUnit.glucoseUnitDisplayString
        keyboardType = .decimalPad
        placeholder = "Enter glucose value"
        delegate = self
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension GlucoseEntryTableViewController: TextFieldTableViewControllerDelegate {
    func textFieldTableViewControllerDidEndEditing(_ controller: TextFieldTableViewController) {
        glucoseEntryDelegate?.glucoseEntryTableViewControllerDidChangeGlucose(self)
    }

    func textFieldTableViewControllerDidReturn(_ controller: TextFieldTableViewController) {
        glucoseEntryDelegate?.glucoseEntryTableViewControllerDidChangeGlucose(self)
    }
}
