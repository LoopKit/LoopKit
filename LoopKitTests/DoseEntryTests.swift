//
//  DoseEntryTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 5/4/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit

@testable import LoopKit

class DoseEntryCodableTests: XCTestCase {
    func testCodable() throws {
        try assertDoseEntryCodable(DoseEntry(type: .tempBasal,
                                             startDate: Date(),
                                             endDate: Date().addingTimeInterval(.minutes(30)),
                                             value: 1.25,
                                             unit: .unitsPerHour,
                                             deliveredUnits: 0.5,
                                             description: "Temporary Basal",
                                             syncIdentifier: UUID().uuidString,
                                             scheduledBasalRate: HKQuantity(unit: DoseEntry.unitsPerHour, doubleValue: 1.0)))
    }
    
    func assertDoseEntryCodable(_ original: DoseEntry) throws {
        let data = try PropertyListEncoder().encode(original)
        let decoded = try PropertyListDecoder().decode(DoseEntry.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
