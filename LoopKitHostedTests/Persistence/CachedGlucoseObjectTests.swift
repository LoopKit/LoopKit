//
//  CachedGlucoseObjectTests.swift
//  LoopKitHostedTests
//
//  Created by Darin Krauss on 10/12/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
@testable import LoopKit

class CachedGlucoseObjectOperationsTests: PersistenceControllerTestCase {
    func testCreateFromNewGlucoseSample() {
        cacheStore.managedObjectContext.performAndWait {
            let startDate = dateFormatter.date(from: "2020-01-02T03:04:05Z")!
            let quantity = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 123.4)
            let newGlucoseSample = NewGlucoseSample(date: startDate,
                                                    quantity: quantity,
                                                    isDisplayOnly: true,
                                                    wasUserEntered: false,
                                                    syncIdentifier: "F4C094AA-9EBE-4804-8F02-90C7B613BDEC",
                                                    syncVersion: 2,
                                                    device: nil)
            let object = CachedGlucoseObject(context: cacheStore.managedObjectContext)
            object.create(from: newGlucoseSample, provenanceIdentifier: "06173C6A-4945-4139-A77D-E3ABC3221EA9")
            XCTAssertNil(object.uuid)
            XCTAssertEqual(object.provenanceIdentifier, "06173C6A-4945-4139-A77D-E3ABC3221EA9")
            XCTAssertEqual(object.syncIdentifier, "F4C094AA-9EBE-4804-8F02-90C7B613BDEC")
            XCTAssertEqual(object.primitiveSyncVersion, 2)
            XCTAssertEqual(object.value, quantity.doubleValue(for: .milligramsPerDeciliter))
            XCTAssertEqual(object.unitString, HKUnit.milligramsPerDeciliter.unitString)
            XCTAssertEqual(object.startDate, startDate)
            XCTAssertEqual(object.isDisplayOnly, true)
            XCTAssertEqual(object.wasUserEntered, false)
            XCTAssertEqual(object.modificationCounter, 1)
        }
    }

    func testCreateFromQuantitySample() {
        cacheStore.managedObjectContext.performAndWait {
            let type = HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!
            let startDate = dateFormatter.date(from: "2020-02-03T04:05:06Z")!
            let quantity = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 123.4)
            let metadata: [String: Any] = [
                HKMetadataKeySyncIdentifier: "0B2353CD-7F98-4297-81E2-8D6FCDD02655",
                HKMetadataKeySyncVersion: 2,
                MetadataKeyGlucoseIsDisplayOnly: false,
                HKMetadataKeyWasUserEntered: true
            ]
            let quantitySample = HKQuantitySample(type: type, quantity: quantity, start: startDate, end: startDate, metadata: metadata)
            let object = CachedGlucoseObject(context: cacheStore.managedObjectContext)
            object.create(from: quantitySample)
            XCTAssertNotNil(object.uuid)
            XCTAssertEqual(object.provenanceIdentifier, "")
            XCTAssertEqual(object.syncIdentifier, "0B2353CD-7F98-4297-81E2-8D6FCDD02655")
            XCTAssertEqual(object.primitiveSyncVersion, 2)
            XCTAssertEqual(object.value, quantity.doubleValue(for: .milligramsPerDeciliter))
            XCTAssertEqual(object.unitString, HKUnit.milligramsPerDeciliter.unitString)
            XCTAssertEqual(object.startDate, startDate)
            XCTAssertEqual(object.isDisplayOnly, false)
            XCTAssertEqual(object.wasUserEntered, true)
            XCTAssertEqual(object.modificationCounter, 1)
        }
    }

    private let dateFormatter = ISO8601DateFormatter()
}
