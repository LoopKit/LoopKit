//
//  SharedDeviceConfigurationTests.swift
//  LoopKitTests
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit

class SharedDeviceConfigurationTests: XCTestCase {

    func testRawValueRoundTripsTheHeaderAndLeavesTheStateOpaque() {
        let asOf = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let configuration = SharedDeviceConfiguration(managerIdentifier: "Pump", asOf: asOf, deliveredUnits: 12.35,
                                                      state: ["key": "value", "nested": ["n": 1]])

        let restored = SharedDeviceConfiguration(rawValue: configuration.rawValue)

        XCTAssertEqual(restored?.managerIdentifier, "Pump")
        XCTAssertEqual(restored?.asOf, asOf)
        XCTAssertEqual(restored?.deliveredUnits, 12.35)
        XCTAssertEqual(restored?.state["key"] as? String, "value")
        XCTAssertEqual((restored?.state["nested"] as? [String: Any])?["n"] as? Int, 1)
    }

    func testDeliveredUnitsIsOptional() {
        let configuration = SharedDeviceConfiguration(managerIdentifier: "CGM", asOf: Date(), state: [:])
        XCTAssertNil(configuration.rawValue["deliveredUnits"])
        XCTAssertNotNil(SharedDeviceConfiguration(rawValue: configuration.rawValue))
        XCTAssertNil(SharedDeviceConfiguration(rawValue: configuration.rawValue)?.deliveredUnits)
    }

    func testAnIncompleteRawValueIsRefused() {
        XCTAssertNil(SharedDeviceConfiguration(rawValue: ["managerIdentifier": "Pump", "state": [:]]))
        XCTAssertNil(SharedDeviceConfiguration(rawValue: ["asOf": Date(), "state": [:]]))
        XCTAssertNil(SharedDeviceConfiguration(rawValue: ["managerIdentifier": "Pump", "asOf": Date()]))
    }

    func testTheRawValueIsAPropertyList() throws {
        let configuration = SharedDeviceConfiguration(managerIdentifier: "Pump", asOf: Date(), deliveredUnits: 1,
                                                      state: ["data": Data([1, 2]), "date": Date()])
        let data = try PropertyListSerialization.data(fromPropertyList: configuration.rawValue, format: .binary, options: 0)
        let decoded = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        XCTAssertEqual(decoded.flatMap(SharedDeviceConfiguration.init(rawValue:))?.state["data"] as? Data, Data([1, 2]))
    }
}
