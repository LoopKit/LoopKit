//
//  PumpManagerStatusTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 5/4/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit

@testable import LoopKit

class PumpManagerStatusCodableTests: XCTestCase {
    func testCodable() throws {
        let device = HKDevice(name: "Acme Best Device",
                              manufacturer: "Acme",
                              model: "Best",
                              hardwareVersion: "0.1.2",
                              firmwareVersion: "1.2.3",
                              softwareVersion: "2.3.4",
                              localIdentifier: "Locally Identified",
                              udiDeviceIdentifier: "U0D1I2")
        try assertPumpManagerStatusCodable(PumpManagerStatus(timeZone: TimeZone(identifier: "America/Los_Angeles")!,
                                                             device: device,
                                                             pumpBatteryChargeRemaining: 0.75,
                                                             basalDeliveryState: .active(dateFormatter.date(from: "2020-05-14T15:56:09Z")!),
                                                             bolusState: .noBolus,
                                                             insulinType: .novolog,
                                                             deliveryIsUncertain: true),
                                           encodesJSON: """
{
  "basalDeliveryState" : {
    "active" : {
      "at" : "2020-05-14T15:56:09Z"
    }
  },
  "bolusState" : "noBolus",
  "deliveryIsUncertain" : true,
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
  "insulinType" : 0,
  "pumpBatteryChargeRemaining" : 0.75,
  "timeZone" : {
    "identifier" : "America/Los_Angeles"
  }
}
"""
        )
    }

    func testCodableRequiredOnly() throws {
        let device = HKDevice(name: nil,
                              manufacturer: nil,
                              model: nil,
                              hardwareVersion: nil,
                              firmwareVersion: nil,
                              softwareVersion: nil,
                              localIdentifier: nil,
                              udiDeviceIdentifier: "U0D1I2")
        try assertPumpManagerStatusCodable(PumpManagerStatus(timeZone: TimeZone(identifier: "America/Los_Angeles")!,
                                                             device: device,
                                                             pumpBatteryChargeRemaining: nil,
                                                             basalDeliveryState: nil,
                                                             bolusState: .noBolus,
                                                             insulinType: nil,
                                                             deliveryIsUncertain: true),
                                           encodesJSON: """
{
  "bolusState" : "noBolus",
  "deliveryIsUncertain" : true,
  "device" : {
    "udiDeviceIdentifier" : "U0D1I2"
  },
  "timeZone" : {
    "identifier" : "America/Los_Angeles"
  }
}
"""
        )
    }

    private func assertPumpManagerStatusCodable(_ original: PumpManagerStatus, encodesJSON string: String) throws {
        let data = try encoder.encode(original)
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
        let decoded = try decoder.decode(PumpManagerStatus.self, from: data)
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

class PumpManagerStatusBasalDeliveryStateCodableTests: XCTestCase {
    func testCodableActive() throws {
        try assertPumpManagerStatusBasalDeliveryStateCodable(.active(dateFormatter.date(from: "2020-05-14T12:18:09Z")!), encodesJSON: """
{
  "basalDeliveryState" : {
    "active" : {
      "at" : "2020-05-14T12:18:09Z"
    }
  }
}
"""
        )
    }

    func testCodableInitiatingTempBasal() throws {
        try assertPumpManagerStatusBasalDeliveryStateCodable(.initiatingTempBasal, encodesJSON: """
{
  "basalDeliveryState" : "initiatingTempBasal"
}
"""
        )
    }

    func testCodableTempBasal() throws {
        let dose = DoseEntry(type: .tempBasal,
                             startDate: dateFormatter.date(from: "2020-05-14T13:13:14Z")!,
                             endDate: dateFormatter.date(from: "2020-05-14T13:43:14Z")!,
                             value: 1.25,
                             unit: .unitsPerHour,
                             deliveredUnits: 0.5,
                             description: "Temporary Basal",
                             syncIdentifier: "238E41EA-9576-4981-A1A4-51E10228584F",
                             scheduledBasalRate: HKQuantity(unit: DoseEntry.unitsPerHour, doubleValue: 1.0))
        try assertPumpManagerStatusBasalDeliveryStateCodable(.tempBasal(dose), encodesJSON: """
{
  "basalDeliveryState" : {
    "tempBasal" : {
      "dose" : {
        "deliveredUnits" : 0.5,
        "description" : "Temporary Basal",
        "endDate" : "2020-05-14T13:43:14Z",
        "isMutable" : false,
        "manuallyEntered" : false,
        "scheduledBasalRate" : 1,
        "scheduledBasalRateUnit" : "IU/hr",
        "startDate" : "2020-05-14T13:13:14Z",
        "syncIdentifier" : "238E41EA-9576-4981-A1A4-51E10228584F",
        "type" : "tempBasal",
        "unit" : "U/hour",
        "value" : 1.25,
        "wasProgrammedByPumpUI" : false
      }
    }
  }
}
"""
        )
    }

    func testCodableCancelingTempBasal() throws {
        try assertPumpManagerStatusBasalDeliveryStateCodable(.cancelingTempBasal, encodesJSON: """
{
  "basalDeliveryState" : "cancelingTempBasal"
}
"""
        )
    }

    func testCodableSuspending() throws {
        try assertPumpManagerStatusBasalDeliveryStateCodable(.suspending, encodesJSON: """
{
  "basalDeliveryState" : "suspending"
}
"""
        )
    }

    func testCodableSuspended() throws {
        try assertPumpManagerStatusBasalDeliveryStateCodable(.suspended(dateFormatter.date(from: "2020-05-14T22:38:19Z")!), encodesJSON: """
{
  "basalDeliveryState" : {
    "suspended" : {
      "at" : "2020-05-14T22:38:19Z"
    }
  }
}
"""
        )
    }

    func testCodableResuming() throws {
        try assertPumpManagerStatusBasalDeliveryStateCodable(.resuming, encodesJSON: """
{
  "basalDeliveryState" : "resuming"
}
"""
        )
    }

    private func assertPumpManagerStatusBasalDeliveryStateCodable(_ original: PumpManagerStatus.BasalDeliveryState, encodesJSON string: String) throws {
        let data = try encoder.encode(TestContainer(basalDeliveryState: original))
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
        let decoded = try decoder.decode(TestContainer.self, from: data)
        XCTAssertEqual(decoded.basalDeliveryState, original)
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

    private struct TestContainer: Codable, Equatable {
        let basalDeliveryState: PumpManagerStatus.BasalDeliveryState
    }
}

class PumpManagerStatusBolusStateCodableTests: XCTestCase {
    func testCodableNone() throws {
        try assertPumpManagerStatusBolusStateCodable(.noBolus, encodesJSON: """
{
  "bolusState" : "noBolus"
}
"""
        )
    }

    func testCodableInitiating() throws {
        try assertPumpManagerStatusBolusStateCodable(.initiating, encodesJSON: """
{
  "bolusState" : "initiating"
}
"""
        )
    }

    func testCodableInProgress() throws {
        let dose = DoseEntry(type: .bolus,
                             startDate: dateFormatter.date(from: "2020-05-14T22:38:16Z")!,
                             value: 2.5,
                             unit: .units,
                             deliveredUnits: 1.0,
                             description: "Bolus",
                             syncIdentifier: "2A67A303-5203-4CB8-8123-79498265368E",
                             isMutable: true)
        try assertPumpManagerStatusBolusStateCodable(.inProgress(dose), encodesJSON: """
{
  "bolusState" : {
    "inProgress" : {
      "dose" : {
        "deliveredUnits" : 1,
        "description" : "Bolus",
        "endDate" : "2020-05-14T22:38:16Z",
        "isMutable" : true,
        "manuallyEntered" : false,
        "startDate" : "2020-05-14T22:38:16Z",
        "syncIdentifier" : "2A67A303-5203-4CB8-8123-79498265368E",
        "type" : "bolus",
        "unit" : "U",
        "value" : 2.5,
        "wasProgrammedByPumpUI" : false
      }
    }
  }
}
"""
        )
    }

    func testCodableCancelling() throws {
        try assertPumpManagerStatusBolusStateCodable(.canceling, encodesJSON: """
{
  "bolusState" : "canceling"
}
"""
        )
    }

    private func assertPumpManagerStatusBolusStateCodable(_ original: PumpManagerStatus.BolusState, encodesJSON string: String) throws {
        let data = try encoder.encode(TestContainer(bolusState: original))
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
        let decoded = try decoder.decode(TestContainer.self, from: data)
        XCTAssertEqual(decoded.bolusState, original)
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

    private struct TestContainer: Codable, Equatable {
        let bolusState: PumpManagerStatus.BolusState
    }
}
