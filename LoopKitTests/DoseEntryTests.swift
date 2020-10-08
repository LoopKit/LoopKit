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
                                             startDate: dateFormatter.date(from: "2020-05-14T22:07:19Z")!,
                                             endDate: dateFormatter.date(from: "2020-05-14T22:37:19Z")!,
                                             value: 1.25,
                                             unit: .unitsPerHour,
                                             deliveredUnits: 0.5,
                                             description: "Temporary Basal",
                                             syncIdentifier: "238E41EA-9576-4981-A1A4-51E10228584F",
                                             scheduledBasalRate: HKQuantity(unit: DoseEntry.unitsPerHour, doubleValue: 1.5)),
        encodesJSON: """
{
  "deliveredUnits" : 0.5,
  "description" : "Temporary Basal",
  "endDate" : "2020-05-14T22:37:19Z",
  "scheduledBasalRate" : 1.5,
  "scheduledBasalRateUnit" : "IU/hr",
  "startDate" : "2020-05-14T22:07:19Z",
  "syncIdentifier" : "238E41EA-9576-4981-A1A4-51E10228584F",
  "type" : "tempBasal",
  "unit" : "U/hour",
  "value" : 1.25
}
"""
        )
    }
    
    private func assertDoseEntryCodable(_ original: DoseEntry, encodesJSON string: String) throws {
        let data = try encoder.encode(original)
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
        let decoded = try decoder.decode(DoseEntry.self, from: data)
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
