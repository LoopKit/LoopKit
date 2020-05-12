//
//  GlucoseValueTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 5/4/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit

@testable import LoopKit

class SimpleGlucoseValueTests: XCTestCase {
    func testInitializerMilligramsPerDeciliter() {
        let startDate = Date()
        let endDate = Date().addingTimeInterval(.hours(1))
        let quantity = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 234.5)
        let simpleGlucoseValue = SimpleGlucoseValue(startDate: startDate, endDate: endDate, quantity: quantity)
        XCTAssertEqual(simpleGlucoseValue.startDate, startDate)
        XCTAssertEqual(simpleGlucoseValue.endDate, endDate)
        XCTAssertEqual(simpleGlucoseValue.quantity, quantity)
    }

    func testInitializerMillimolesPerLiter() {
        let startDate = Date()
        let endDate = Date().addingTimeInterval(.hours(1))
        let quantity = HKQuantity(unit: .millimolesPerLiter, doubleValue: 12.3)
        let simpleGlucoseValue = SimpleGlucoseValue(startDate: startDate, endDate: endDate, quantity: quantity)
        XCTAssertEqual(simpleGlucoseValue.startDate, startDate)
        XCTAssertEqual(simpleGlucoseValue.endDate, endDate)
        XCTAssertEqual(simpleGlucoseValue.quantity, quantity)
    }

    func testInitializerMissingEndDate() {
        let startDate = Date()
        let quantity = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 234.5)
        let simpleGlucoseValue = SimpleGlucoseValue(startDate: startDate, quantity: quantity)
        XCTAssertEqual(simpleGlucoseValue.startDate, startDate)
        XCTAssertEqual(simpleGlucoseValue.endDate, startDate)
        XCTAssertEqual(simpleGlucoseValue.quantity, quantity)
    }

    func testInitializerGlucoseValue() {
        let startDate = Date()
        let endDate = Date().addingTimeInterval(.hours(1))
        let quantity = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 234.5)
        let simpleGlucoseValue = SimpleGlucoseValue(SimpleGlucoseValue(startDate: startDate, endDate: endDate, quantity: quantity))
        XCTAssertEqual(simpleGlucoseValue.startDate, startDate)
        XCTAssertEqual(simpleGlucoseValue.endDate, endDate)
        XCTAssertEqual(simpleGlucoseValue.quantity, quantity)
    }
}

class SimpleGlucoseValueCodableTests: XCTestCase {
    func testCodableMilligramsPerDeciliter() throws {
        try assertSimpleGlucoseValueCodable(SimpleGlucoseValue(startDate: Date(),
                                                               endDate: Date().addingTimeInterval(.hours(1)),
                                                               quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 234.5)))
    }

    func testCodableMillimolesPerLiter() throws {
        try assertSimpleGlucoseValueCodable(SimpleGlucoseValue(startDate: Date(),
                                                               endDate: Date().addingTimeInterval(.hours(1)),
                                                               quantity: HKQuantity(unit: .millimolesPerLiter, doubleValue: 12.3)))
    }

    func assertSimpleGlucoseValueCodable(_ original: SimpleGlucoseValue) throws {
        let data = try PropertyListEncoder().encode(original)
        let decoded = try PropertyListDecoder().decode(SimpleGlucoseValue.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}

class PredictedGlucoseValueCodableTests: XCTestCase {
    func testCodableMilligramsPerDeciliter() throws {
        try assertPredictedGlucoseValueCodable(PredictedGlucoseValue(startDate: Date(),
                                                                     quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 234.5)))
    }

    func testCodableMillimolesPerLiter() throws {
        try assertPredictedGlucoseValueCodable(PredictedGlucoseValue(startDate: Date(),
                                                                     quantity: HKQuantity(unit: .millimolesPerLiter, doubleValue: 12.3)))
    }

    func assertPredictedGlucoseValueCodable(_ original: PredictedGlucoseValue) throws {
        let data = try PropertyListEncoder().encode(original)
        let decoded = try PropertyListDecoder().decode(PredictedGlucoseValue.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
