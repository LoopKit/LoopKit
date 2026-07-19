//
//  ChartAxisValueDoubleLog.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/29/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation


/// A signed logarithmic transform used by the dose chart so large boluses don't dwarf basal rates.
///
/// Values are plotted at `sign(x) * log(|x| + 1)` and converted back for display.
public enum ChartLogScale {
    /// Converts an actual value into its plotted (signed-log) position.
    public static func toPlot(_ actual: Double) -> Double {
        switch actual {
        case let x where x < 0:
            return -log(-x + 1)
        case let x where x > 0:
            return log(x + 1)
        default:  // 0
            return 0
        }
    }

    /// Converts a plotted (signed-log) position back into an actual value.
    public static func fromPlot(_ plot: Double) -> Double {
        switch plot {
        case let x where x < 0:
            return -pow(M_E, -x) + 1
        case let x where x > 0:
            return pow(M_E, x) - 1
        default:  // 0
            return 0
        }
    }
}
