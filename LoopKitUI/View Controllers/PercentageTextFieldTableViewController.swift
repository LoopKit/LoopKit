//
//  PercentageTextFieldTableViewController.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 11/23/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit


protocol PercentageTextFieldTableViewControllerDelegate: class {
    func percentageTextFieldTableViewControllerDidChangePercentage(_ controller: PercentageTextFieldTableViewController)
}

class PercentageTextFieldTableViewController: TextFieldTableViewController {

    var percentage: Double? {
        get {
            return value.flatMap(Double.init)
        }
        set {
            value = percentage.flatMap(percentageFormatter.string(from:))
        }
    }

    weak var percentageDelegate: PercentageTextFieldTableViewControllerDelegate?

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

    convenience init() {
        self.init(style: .grouped)
        unit = "%"
        keyboardType = .decimalPad
        placeholder = "Enter percentage"
        delegate = self
    }
}

extension PercentageTextFieldTableViewController: TextFieldTableViewControllerDelegate {
    func textFieldTableViewControllerDidEndEditing(_ controller: TextFieldTableViewController) {
        percentageDelegate?.percentageTextFieldTableViewControllerDidChangePercentage(self)
    }

    func textFieldTableViewControllerDidReturn(_ controller: TextFieldTableViewController) {
        percentageDelegate?.percentageTextFieldTableViewControllerDidChangePercentage(self)
    }
}
