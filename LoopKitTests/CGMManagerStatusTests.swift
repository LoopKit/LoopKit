//
//  CGMManagerStatusTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 11/3/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit

@testable import LoopKit

class CGMManagerStatusCodableTests: XCTestCase {
    func testCodable() throws {
        let device = HKDevice(name: "Acme Best Device",
                              manufacturer: "Acme",
                              model: "Best",
                              hardwareVersion: "0.1.2",
                              firmwareVersion: "1.2.3",
                              softwareVersion: "2.3.4",
                              localIdentifier: "Locally Identified",
                              udiDeviceIdentifier: "U0D1I2")
        try assertCGMManagerStatusCodable(CGMManagerStatus(hasValidSensorSession: true,
                                                           lastCommunicationDate: dateFormatter.date(from: "2020-05-14T15:56:09Z")!,
                                                           device: device),
                                           encodesJSON: """
{
  "device" : {
    "firmwareVersion" : "1.2.3",
    "hardwareVersion" : "0.1.2",
    "localIdentifier" : "Locally Identified",
    "manufacturer" : "Acme",
    "model" : "Best",
    "name" : "Acme Best Device",
    "softwareVersion" : "2.3.4",
    "udiDeviceIdentifier" : "U0D1I2"
  },
  "hasValidSensorSession" : true,
  "lastCommunicationDate" : "2020-05-14T15:56:09Z"
}
"""
        )
    }

    private func assertCGMManagerStatusCodable(_ original: CGMManagerStatus, encodesJSON string: String) throws {
        let data = try encoder.encode(original)
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
        let decoded = try decoder.decode(CGMManagerStatus.self, from: data)
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
