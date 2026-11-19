//
//  NewPumpEventTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 1/13/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit

class NewPumpEventRawRepresentableTests: XCTestCase {
    func testNewPumpEventRawRepresentable() {
        let original = NewPumpEvent(date: Date(),
                                    dose: DoseEntry(type: .tempBasal,
                                                    startDate: Date(),
                                                    endDate: Date().addingTimeInterval(.minutes(30)),
                                                    value: 1.5,
                                                    unit: .unitsPerHour,
                                                    doseId: nil,
                                                    deliveredUnits: 0.5,
                                                    description: "Test Dose Entry",
                                                    syncIdentifier: UUID().uuidString,
                                                    scheduledBasalRate: LoopQuantity(unit: .internationalUnitsPerHour, doubleValue: 2.0),
                                                    insulinType: .fiasp,
                                                    automatic: true,
                                                    manuallyEntered: false,
                                                    isMutable: true,
                                                    wasProgrammedByPumpUI: true),
                                    raw: Data(UUID().uuidString.utf8),
                                    title: "Test Pump Event",
                                    type: .tempBasal,
                                    alarmType: .occlusion)
        let actual = NewPumpEvent(rawValue: original.rawValue)
        XCTAssertEqual(actual, original)
    }

    func testComponentReplacementRawRepresentable() {
        let replacement = ComponentReplacement(previousStopDate: Date(timeIntervalSinceReferenceDate: 1000),
                                               reason: .fault,
                                               faultCode: "0x14",
                                               previousRemainingUnits: 12.5,
                                               primes: [.init(target: .cannula, volume: 0.5)],
                                               expirationDate: Date(timeIntervalSinceReferenceDate: 300_000),
                                               componentIdentifier: "L1-S2")
        let original = NewPumpEvent(date: Date(timeIntervalSinceReferenceDate: 2000),
                                    dose: nil,
                                    raw: Data("Pod Change".utf8),
                                    title: "Pod Change",
                                    type: .replaceComponent(componentType: .pump),
                                    componentReplacement: replacement)
        let actual = NewPumpEvent(rawValue: original.rawValue)
        XCTAssertEqual(actual, original)
        XCTAssertEqual(actual?.componentReplacement, replacement)
    }

    func testComponentReplacementDecodesAnUnknownReason() throws {
        let data = Data(#"{"primes":[],"reason":"somethingNew"}"#.utf8)
        XCTAssertEqual(try ComponentReplacement(encoded: data).reason, .unknown)
    }
}
