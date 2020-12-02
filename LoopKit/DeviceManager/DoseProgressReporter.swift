//
//  DoseProgressReporter.swift
//  LoopKit
//
//  Created by Pete Schwamb on 3/12/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation


public struct DoseProgress {
    public let deliveredUnits: Double
    public let percentComplete: Double

    public var isComplete: Bool {
        return percentComplete >= 1.0 || fabs(percentComplete - 1.0) <= Double.ulpOfOne
    }

    public init(deliveredUnits: Double, percentComplete: Double) {
        self.deliveredUnits = deliveredUnits
        self.percentComplete = percentComplete
    }
}

public protocol DoseProgressObserver: class {
    func doseProgressReporterDidUpdate(_ doseProgressReporter: DoseProgressReporter)
}

public protocol DoseProgressReporter: class {
    var progress: DoseProgress { get }

    func addObserver(_ observer: DoseProgressObserver)

    func removeObserver(_ observer: DoseProgressObserver)
}
