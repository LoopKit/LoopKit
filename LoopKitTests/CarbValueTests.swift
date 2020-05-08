//
//  CarbValueTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 5/4/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit

@testable import LoopKit

class CarbValueCodableTests: XCTestCase {
    func testCodable() throws {
        try assertCarbValueCodable(CarbValue(startDate: Date(),
                                             endDate: Date().addingTimeInterval(.hours(1)),
                                             quantity: HKQuantity(unit: .gram(), doubleValue: 34.5)))
    }

    func assertCarbValueCodable(_ original: CarbValue) throws {
        let data = try PropertyListEncoder().encode(original)
        let decoded = try PropertyListDecoder().decode(CarbValue.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
