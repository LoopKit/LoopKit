//
//  PercentageTextFieldTableViewController.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 11/23/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit


public protocol PercentageTextFieldTableViewControllerDelegate: class {
    func percentageTextFieldTableViewControllerDidChangePercentage(_ controller: PercentageTextFieldTableViewController)
}

public class PercentageTextFieldTableViewController: TextFieldTableViewController {

    public var percentage: Double? {
        get {
            if let doubleValue = value.flatMap(Double.init) {
                return doubleValue / 100
            } else {
                return nil
            }
        }
        set {
            if let percentage = newValue {
                value = percentageFormatter.string(from: percentage * 100)
            } else {
                value = nil
            }
        }
    }

    public weak var percentageDelegate: PercentageTextFieldTableViewControllerDelegate?

    var maximumFractionDigits: Int = 1 {
        didSet {
            percentageFormatter.maximumFractionDigits = maximumFractionDigits
        }
    }

    private lazy var percentageFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumIntegerDigits = 1
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter
    }()

    public convenience init() {
        self.init(style: .grouped)
        unit = "%"
        keyboardType = .decimalPad
        placeholder = "Enter percentage"
        delegate = self
    }
}

extension PercentageTextFieldTableViewController: TextFieldTableViewControllerDelegate {
    public func textFieldTableViewControllerDidEndEditing(_ controller: TextFieldTableViewController) {
        percentageDelegate?.percentageTextFieldTableViewControllerDidChangePercentage(self)
    }

    public func textFieldTableViewControllerDidReturn(_ controller: TextFieldTableViewController) {
        percentageDelegate?.percentageTextFieldTableViewControllerDidChangePercentage(self)
    }
}
