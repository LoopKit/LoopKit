//
//  TempBasalRecommendation.swift
//  LoopKit
//
//  Created by Darin Krauss on 5/21/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public struct TempBasalRecommendation: Equatable {
    public let unitsPerHour: Double
    public let duration: TimeInterval

    public var rateQuantity: HKQuantity {
        return HKQuantity(unit: .internationalUnitsPerHour, doubleValue: unitsPerHour)
    }

    /// A special command which cancels any existing temp basals
    public static var cancel: TempBasalRecommendation {
        return self.init(unitsPerHour: 0, duration: 0)
    }

    public init(unitsPerHour: Double, duration: TimeInterval) {
        self.unitsPerHour = unitsPerHour
        self.duration = duration
    }
}

extension TempBasalRecommendation: Codable {}
