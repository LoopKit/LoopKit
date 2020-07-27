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
        try assertCarbValueCodable(CarbValue(startDate: dateFormatter.date(from: "2020-05-14T12:18:14Z")!,
                                             endDate: dateFormatter.date(from: "2020-05-14T13:18:14Z")!,
                                             quantity: HKQuantity(unit: .gram(), doubleValue: 34.5)),
                                   encodesJSON: """
{
  "endDate" : "2020-05-14T13:18:14Z",
  "quantity" : 34.5,
  "quantityUnit" : "g",
  "startDate" : "2020-05-14T12:18:14Z"
}
"""
        )
    }

    private func assertCarbValueCodable(_ original: CarbValue, encodesJSON string: String) throws {
        let data = try encoder.encode(original)
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
        let decoded = try decoder.decode(CarbValue.self, from: data)
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
