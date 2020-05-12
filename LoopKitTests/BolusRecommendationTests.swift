//
//  BolusRecommendationTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 5/4/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit

@testable import LoopKit

class BolusRecommendationNoticeCodableTests: XCTestCase {
    func testCodableGlucoseBelowSuspendThreshold() throws {
        let glucoseValue = SimpleGlucoseValue(startDate: Date(), quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 65.0))
        try assertBolusRecommendationNoticeCodable(.glucoseBelowSuspendThreshold(minGlucose: glucoseValue))
    }

    func testCodableCurrentGlucoseBelowTarget() throws {
        let glucoseValue = SimpleGlucoseValue(startDate: Date(), quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 85.0))
        try assertBolusRecommendationNoticeCodable(.currentGlucoseBelowTarget(glucose: glucoseValue))
    }

    func testCodablePredictedGlucoseBelowTarget() throws {
        let glucoseValue = SimpleGlucoseValue(startDate: Date(), quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 80.0))
        try assertBolusRecommendationNoticeCodable(.predictedGlucoseBelowTarget(minGlucose: glucoseValue))
    }

    func assertBolusRecommendationNoticeCodable(_ original: BolusRecommendationNotice) throws {
        let data = try PropertyListEncoder().encode(TestContainer(bolusRecommendationNotice: original))
        let decoded = try PropertyListDecoder().decode(TestContainer.self, from: data)
        XCTAssertEqual(decoded.bolusRecommendationNotice, original)
    }

    private struct TestContainer: Codable, Equatable {
        let bolusRecommendationNotice: BolusRecommendationNotice
    }
}

extension BolusRecommendationNotice: Equatable {
    public static func == (lhs: BolusRecommendationNotice, rhs: BolusRecommendationNotice) -> Bool {
        switch (lhs, rhs) {
        case (.glucoseBelowSuspendThreshold(let lhsGlucoseValue), .glucoseBelowSuspendThreshold(let rhsGlucoseValue)),
             (.currentGlucoseBelowTarget(let lhsGlucoseValue), .currentGlucoseBelowTarget(let rhsGlucoseValue)),
             (.predictedGlucoseBelowTarget(let lhsGlucoseValue), .predictedGlucoseBelowTarget(let rhsGlucoseValue)):
            return lhsGlucoseValue.startDate == rhsGlucoseValue.startDate &&
                lhsGlucoseValue.endDate == rhsGlucoseValue.endDate &&
                lhsGlucoseValue.quantity == rhsGlucoseValue.quantity
        default:
            return false
        }
    }
}
