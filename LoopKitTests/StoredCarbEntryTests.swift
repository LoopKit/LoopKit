//
//  StoredCarbEntryTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 10/6/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
@testable import LoopKit

class StoredCarbEntryCodableTests: XCTestCase {
    func testCodable() throws {
        let storedCarbEntry = StoredCarbEntry(uuid: UUID(uuidString: "18CF3948-0B3D-4B12-8BFE-14986B0E6784")!,
                                              provenanceIdentifier: "com.loopkit.loop",
                                              syncIdentifier: "2B03D96C-6F5D-4140-99CD-80C3E64D6010",
                                              syncVersion: 2,
                                              startDate: dateFormatter.date(from: "2020-01-02T03:00:23Z")!,
                                              quantity: HKQuantity(unit: .gram(), doubleValue: 19),
                                              foodType: "Pizza",
                                              absorptionTime: .hours(5),
                                              createdByCurrentApp: true,
                                              userCreatedDate: dateFormatter.date(from: "2020-01-02T03:03:34Z")!,
                                              userUpdatedDate: dateFormatter.date(from: "2020-01-02T03:05:45Z")!)
        try! assertStoredCarbEntryCodable(storedCarbEntry, encodesJSON: """
{
  "absorptionTime" : 18000,
  "createdByCurrentApp" : true,
  "foodType" : "Pizza",
  "provenanceIdentifier" : "com.loopkit.loop",
  "quantity" : 19,
  "startDate" : "2020-01-02T03:00:23Z",
  "syncIdentifier" : "2B03D96C-6F5D-4140-99CD-80C3E64D6010",
  "syncVersion" : 2,
  "userCreatedDate" : "2020-01-02T03:03:34Z",
  "userUpdatedDate" : "2020-01-02T03:05:45Z",
  "uuid" : "18CF3948-0B3D-4B12-8BFE-14986B0E6784"
}
"""
        )
    }

    func testCodableOptional() throws {
        let storedCarbEntry = StoredCarbEntry(uuid: nil,
                                              provenanceIdentifier: "com.loopkit.loop",
                                              syncIdentifier: nil,
                                              syncVersion: nil,
                                              startDate: dateFormatter.date(from: "2020-02-03T04:16:18Z")!,
                                              quantity: HKQuantity(unit: .gram(), doubleValue: 19),
                                              foodType: nil,
                                              absorptionTime: nil,
                                              createdByCurrentApp: false,
                                              userCreatedDate: nil,
                                              userUpdatedDate: nil)

        try! assertStoredCarbEntryCodable(storedCarbEntry, encodesJSON: """
{
  "createdByCurrentApp" : false,
  "provenanceIdentifier" : "com.loopkit.loop",
  "quantity" : 19,
  "startDate" : "2020-02-03T04:16:18Z"
}
"""
        )
    }

    private func assertStoredCarbEntryCodable(_ original: StoredCarbEntry, encodesJSON string: String) throws {
        let data = try encoder.encode(original)
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
        let decoded = try decoder.decode(StoredCarbEntry.self, from: data)
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

    private let dateFormatter = ISO8601DateFormatter()
}
