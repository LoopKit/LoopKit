//
//  GlucoseTrendTableViewController.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 12/17/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit
import LoopKit
import LoopKitUI


protocol GlucoseTrendTableViewControllerDelegate: AnyObject {
    func glucoseTrendTableViewControllerDidChangeTrend(_ controller: GlucoseTrendTableViewController)
}

final class GlucoseTrendTableViewController: RadioSelectionTableViewController {

    var glucoseTrend: GlucoseTrend? {
        get {
            if let selectedIndex = selectedIndex {
                return GlucoseTrend.allCases[selectedIndex]
            } else {
                return nil
            }
        }
        set {
            if let newValue = newValue {
                selectedIndex = GlucoseTrend.allCases.firstIndex(of: newValue)
            } else {
                selectedIndex = nil
            }
        }
    }

    weak var glucoseTrendDelegate: GlucoseTrendTableViewControllerDelegate?

    convenience init() {
        self.init(style: .grouped)
        options = GlucoseTrend.allCases.map { trend in
            "\(trend.symbol)  \(trend.localizedDescription)"
        }
        delegate = self
    }
}

extension GlucoseTrendTableViewController: RadioSelectionTableViewControllerDelegate {
    func radioSelectionTableViewControllerDidChangeSelectedIndex(_ controller: RadioSelectionTableViewController) {
        glucoseTrendDelegate?.glucoseTrendTableViewControllerDidChangeTrend(self)
    }
}
