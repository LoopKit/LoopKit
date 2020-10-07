//
//  StoredInsulinModelTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 8/26/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit

class StoredInsulinModelCodableTests: XCTestCase {
    func testCodable() throws {
        let storedInsulinModel = StoredInsulinModel(modelType: .rapidAdult, actionDuration: .hours(6), peakActivity: .hours(3))
        try! assertStoredInsulinModelCodable(storedInsulinModel, encodesJSON: """
{
  "actionDuration" : 21600,
  "modelType" : "rapidAdult",
  "peakActivity" : 10800
}
"""
        )
    }

    func testCodableOptional() throws {
        let storedInsulinModel = StoredInsulinModel(modelType: .rapidChild, actionDuration: .hours(5))
        try! assertStoredInsulinModelCodable(storedInsulinModel, encodesJSON: """
{
  "actionDuration" : 18000,
  "modelType" : "rapidChild"
}
"""
        )
    }

    private func assertStoredInsulinModelCodable(_ original: StoredInsulinModel, encodesJSON string: String) throws {
        let data = try encoder.encode(original)
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
        let decoded = try decoder.decode(StoredInsulinModel.self, from: data)
        XCTAssertEqual(decoded, original)
    }

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
