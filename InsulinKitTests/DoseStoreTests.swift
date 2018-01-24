//
//  DoseStoreTests.swift
//  LoopKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import InsulinKit

class DoseStoreTests: XCTestCase {

    func testPumpEventTypeDoseMigration() {
        let controller = PersistenceController(directoryURL: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true))

        controller.managedObjectContext.performAndWait {
            let event = PumpEvent(entity: PumpEvent.entity(), insertInto: controller.managedObjectContext)

            event.date = Date()
            event.duration = .minutes(30)
            event.unit = .unitsPerHour
            event.type = .tempBasal
            event.value = 0.5
            event.doseType = nil

            XCTAssertNotNil(event.dose)
            XCTAssertEqual(.tempBasal, event.dose!.type)
        }
    }

}
