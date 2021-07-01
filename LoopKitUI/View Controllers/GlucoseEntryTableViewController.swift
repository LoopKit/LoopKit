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


public protocol GlucoseEntryTableViewControllerDelegate: AnyObject {
    func glucoseEntryTableViewControllerDidChangeGlucose(_ controller: GlucoseEntryTableViewController)
}

public class GlucoseEntryTableViewController: TextFieldTableViewController {

    let glucoseUnit: HKUnit

    private lazy var glucoseFormatter: NumberFormatter = {
        let quantityFormatter = QuantityFormatter()
        quantityFormatter.setPreferredNumberFormatter(for: glucoseUnit)
        return quantityFormatter.numberFormatter
    }()

    public var glucose: HKQuantity? {
        get {
            guard let value = value, let doubleValue = Double(value) else {
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

    public weak var glucoseEntryDelegate: GlucoseEntryTableViewControllerDelegate?

    public init(glucoseUnit: HKUnit) {
        self.glucoseUnit = glucoseUnit
        super.init(style: .grouped)
        unit = glucoseUnit.shortLocalizedUnitString()
        keyboardType = .decimalPad
        placeholder = "Enter glucose value"
        delegate = self
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension GlucoseEntryTableViewController: TextFieldTableViewControllerDelegate {
    public func textFieldTableViewControllerDidEndEditing(_ controller: TextFieldTableViewController) {
        glucoseEntryDelegate?.glucoseEntryTableViewControllerDidChangeGlucose(self)
    }

    public func textFieldTableViewControllerDidReturn(_ controller: TextFieldTableViewController) {
        glucoseEntryDelegate?.glucoseEntryTableViewControllerDidChangeGlucose(self)
    }
}
