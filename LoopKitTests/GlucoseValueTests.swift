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
        try assertSimpleGlucoseValueCodable(SimpleGlucoseValue(startDate: dateFormatter.date(from: "2020-05-14T22:00:03Z")!,
                                                               endDate: dateFormatter.date(from: "2020-05-14T23:00:03Z")!,
                                                               quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 234.5)),
                                            encodesJSON: """
{
  "endDate" : "2020-05-14T23:00:03Z",
  "quantity" : 234.5,
  "quantityUnit" : "mg/dL",
  "startDate" : "2020-05-14T22:00:03Z"
}
"""
        )
    }
    
    func testCodableMillimolesPerLiter() throws {
        try assertSimpleGlucoseValueCodable(SimpleGlucoseValue(startDate: dateFormatter.date(from: "2020-05-14T14:05:03Z")!,
                                                               endDate: dateFormatter.date(from: "2020-05-14T15:05:03Z")!,
                                                               quantity: HKQuantity(unit: .millimolesPerLiter, doubleValue: 13.2)),
                                            encodesJSON: """
{
  "endDate" : "2020-05-14T15:05:03Z",
  "quantity" : 237.80576160007135,
  "quantityUnit" : "mg/dL",
  "startDate" : "2020-05-14T14:05:03Z"
}
"""
        )
    }
    
    private func assertSimpleGlucoseValueCodable(_ original: SimpleGlucoseValue, encodesJSON string: String) throws {
        let data = try encoder.encode(original)
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
        let decoded = try decoder.decode(SimpleGlucoseValue.self, from: data)
        XCTAssertEqual(decoded, original)
    }
    
    private let dateFormatter = ISO8601DateFormatter()
    
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

class PredictedGlucoseValueCodableTests: XCTestCase {
    func testCodableMilligramsPerDeciliter() throws {
        try assertPredictedGlucoseValueCodable(PredictedGlucoseValue(startDate: dateFormatter.date(from: "2020-05-14T22:38:26Z")!,
                                                                     quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 234.5)),
                                               encodesJSON: """
{
  "quantity" : 234.5,
  "quantityUnit" : "mg/dL",
  "startDate" : "2020-05-14T22:38:26Z"
}
"""
        )
    }
    
    func testCodableMillimolesPerLiter() throws {
        try assertPredictedGlucoseValueCodable(PredictedGlucoseValue(startDate: dateFormatter.date(from: "2020-05-14T21:23:33Z")!,
                                                                     quantity: HKQuantity(unit: .millimolesPerLiter, doubleValue: 12.3)),
                                               encodesJSON: """
{
  "quantity" : 221.59173240006652,
  "quantityUnit" : "mg/dL",
  "startDate" : "2020-05-14T21:23:33Z"
}
"""
        )
    }
    
    private func assertPredictedGlucoseValueCodable(_ original: PredictedGlucoseValue, encodesJSON string: String) throws {
        let data = try encoder.encode(original)
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
        let decoded = try decoder.decode(PredictedGlucoseValue.self, from: data)
        XCTAssertEqual(decoded, original)
    }
    
    private let dateFormatter = ISO8601DateFormatter()
    
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
