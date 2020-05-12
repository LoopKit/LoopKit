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
        try assertPumpManagerStatusCodable(PumpManagerStatus(timeZone: TimeZone.currentFixed,
                                                             device: device,
                                                             pumpBatteryChargeRemaining: 0.67,
                                                             basalDeliveryState: .active(Date()),
                                                             bolusState: .none))
    }

    func assertPumpManagerStatusCodable(_ original: PumpManagerStatus) throws {
        let data = try PropertyListEncoder().encode(original)
        let decoded = try PropertyListDecoder().decode(PumpManagerStatus.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}

class PumpManagerStatusBasalDeliveryStateCodableTests: XCTestCase {
    func testCodableActive() throws {
        try assertPumpManagerStatusBasalDeliveryStateCodable(.active(Date()))
    }

    func testCodableInitiatingTempBasal() throws {
        try assertPumpManagerStatusBasalDeliveryStateCodable(.initiatingTempBasal)
    }

    func testCodableTempBasal() throws {
        let dose = DoseEntry(type: .tempBasal,
                             startDate: Date(),
                             endDate: Date().addingTimeInterval(.minutes(30)),
                             value: 1.25,
                             unit: .unitsPerHour,
                             deliveredUnits: 0.5,
                             description: "Temporary Basal",
                             syncIdentifier: UUID().uuidString,
                             scheduledBasalRate: HKQuantity(unit: DoseEntry.unitsPerHour, doubleValue: 1.0))
        try assertPumpManagerStatusBasalDeliveryStateCodable(.tempBasal(dose))
    }

    func testCodableCancelingTempBasal() throws {
        try assertPumpManagerStatusBasalDeliveryStateCodable(.cancelingTempBasal)
    }

    func testCodableSuspending() throws {
        try assertPumpManagerStatusBasalDeliveryStateCodable(.suspending)
    }

    func testCodableSuspended() throws {
        try assertPumpManagerStatusBasalDeliveryStateCodable(.suspended(Date()))
    }

    func testCodableResuming() throws {
        try assertPumpManagerStatusBasalDeliveryStateCodable(.resuming)
    }

    func assertPumpManagerStatusBasalDeliveryStateCodable(_ original: PumpManagerStatus.BasalDeliveryState) throws {
        let data = try PropertyListEncoder().encode(TestContainer(basalDeliveryState: original))
        let decoded = try PropertyListDecoder().decode(TestContainer.self, from: data)
        XCTAssertEqual(decoded.basalDeliveryState, original)
    }

    private struct TestContainer: Codable, Equatable {
        let basalDeliveryState: PumpManagerStatus.BasalDeliveryState
    }
}

class PumpManagerStatusBolusStateCodableTests: XCTestCase {
    func testCodableNone() throws {
        try assertPumpManagerStatusBolusStateCodable(.none)
    }

    func testCodableInitiating() throws {
        try assertPumpManagerStatusBolusStateCodable(.initiating)
    }

    func testCodableInProgress() throws {
        let dose = DoseEntry(type: .bolus,
                             startDate: Date(),
                             value: 2.5,
                             unit: .units,
                             deliveredUnits: 1.0,
                             description: "Bolus",
                             syncIdentifier: UUID().uuidString)
        try assertPumpManagerStatusBolusStateCodable(.inProgress(dose))
    }

    func testCodableCancelling() throws {
        try assertPumpManagerStatusBolusStateCodable(.canceling)
    }

    func assertPumpManagerStatusBolusStateCodable(_ original: PumpManagerStatus.BolusState) throws {
        let data = try PropertyListEncoder().encode(TestContainer(bolusState: original))
        let decoded = try PropertyListDecoder().decode(TestContainer.self, from: data)
        XCTAssertEqual(decoded.bolusState, original)
    }

    private struct TestContainer: Codable, Equatable {
        let bolusState: PumpManagerStatus.BolusState
    }
}
