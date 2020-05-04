//
//  BolusRecommendation.swift
//  LoopKit
//
//  Created by Pete Schwamb on 1/2/17.
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import Foundation

public enum BolusRecommendationNotice {
    case glucoseBelowSuspendThreshold(minGlucose: GlucoseValue)
    case currentGlucoseBelowTarget(glucose: GlucoseValue)
    case predictedGlucoseBelowTarget(minGlucose: GlucoseValue)
}

public struct BolusRecommendation {
    public let amount: Double
    public let pendingInsulin: Double
    public var notice: BolusRecommendationNotice?

    public init(amount: Double, pendingInsulin: Double, notice: BolusRecommendationNotice? = nil) {
        self.amount = amount
        self.pendingInsulin = pendingInsulin
        self.notice = notice
    }
}
