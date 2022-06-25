//
//  NewPumpEventTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 1/13/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
import LoopKit

class NewPumpEventRawRepresentableTests: XCTestCase {
    func testNewPumpEventRawRepresentable() {
        let original = NewPumpEvent(date: Date(),
                                    dose: DoseEntry(type: .tempBasal,
                                                    startDate: Date(),
                                                    endDate: Date().addingTimeInterval(.minutes(30)),
                                                    value: 1.5,
                                                    unit: .unitsPerHour,
                                                    deliveredUnits: 0.5,
                                                    description: "Test Dose Entry",
                                                    syncIdentifier: UUID().uuidString,
                                                    scheduledBasalRate: HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 2.0),
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
}
