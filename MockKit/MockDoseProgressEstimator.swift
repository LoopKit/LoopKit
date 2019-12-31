//
//  MockDoseProgressEstimator.swift
//  MockKit
//
//  Created by Pete Schwamb on 3/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit


class MockDoseProgressEstimator: DoseProgressTimerEstimator {

    public let dose: DoseEntry

    override var progress: DoseProgress {
        let elapsed = -dose.startDate.timeIntervalSinceNow
        let duration = dose.endDate.timeIntervalSince(dose.startDate)
        let percentProgress = min(elapsed / duration, 1)
        let delivered = round(percentProgress * dose.programmedUnits * 20) / 20
        return DoseProgress(deliveredUnits: delivered, percentComplete: delivered / dose.programmedUnits)
    }

    public init(reportingQueue: DispatchQueue, dose: DoseEntry) {
        self.dose = dose
        super.init(reportingQueue: reportingQueue)
    }

    override func timerParameters() -> (delay: TimeInterval, repeating: TimeInterval) {
        let timeSinceStart = -dose.startDate.timeIntervalSinceNow
        let timeBetweenPulses: TimeInterval
        switch dose.type {
        case .bolus:
            timeBetweenPulses = TimeInterval(2)
        case .basal, .tempBasal:
            timeBetweenPulses = 0.05 / dose.unitsPerHour * .hours(1)
        default:
            fatalError("Can only estimate progress on basal rates or boluses.")
        }
        let delayUntilNextPulse = timeBetweenPulses - timeSinceStart.remainder(dividingBy: timeBetweenPulses)
        return (delay: delayUntilNextPulse, repeating: timeBetweenPulses)
    }
}
