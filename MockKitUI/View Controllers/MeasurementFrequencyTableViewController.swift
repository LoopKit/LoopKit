//
//  MeasurementFrequencyTableViewController.swift
//  MockKitUI
//
//  Created by Nathaniel Hamming on 2020-06-22.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import UIKit
import LoopKit
import LoopKitUI
import MockKit

protocol MeasurementFrequencyTableViewControllerDelegate: class {
    func measurementFrequencyTableViewControllerDidChangeFrequency(_ controller: MeasurementFrequencyTableViewController)
}

final class MeasurementFrequencyTableViewController: RadioSelectionTableViewController {

    var measurementFrequency: MeasurementFrequency? {
        get {
            if let selectedIndex = selectedIndex {
                return MeasurementFrequency.allCases[selectedIndex]
            } else {
                return nil
            }
        }
        set {
            if let newValue = newValue {
                selectedIndex = MeasurementFrequency.allCases.firstIndex(of: newValue)
            } else {
                selectedIndex = nil
            }
        }
    }

    weak var measurementFrequencyDelegate: MeasurementFrequencyTableViewControllerDelegate?

    convenience init() {
        self.init(style: .grouped)
        options = MeasurementFrequency.allCases.map { frequency in
            "\(frequency.localizedDescription)"
        }
        delegate = self
    }
}

extension MeasurementFrequencyTableViewController: RadioSelectionTableViewControllerDelegate {
    func radioSelectionTableViewControllerDidChangeSelectedIndex(_ controller: RadioSelectionTableViewController) {
        measurementFrequencyDelegate?.measurementFrequencyTableViewControllerDidChangeFrequency(self)
    }
}
