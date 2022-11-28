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
            let device = HKDevice(name: "NAME", manufacturer: "MANUFACTURER", model: "MODEL", hardwareVersion: "HARDWAREVERSION", firmwareVersion: "FIRMWAREVERSION", softwareVersion: "SOFTWAREVERSION", localIdentifier: "LOCALIDENTIFIER", udiDeviceIdentifier: "UDIDEVICEIDENTIFIER")
            let newGlucoseSample = NewGlucoseSample(date: startDate,
                                                    quantity: quantity,
                                                    condition: .belowRange,
                                                    trend: .flat,
                                                    trendRate: HKQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: 0.1),
                                                    isDisplayOnly: true,
                                                    wasUserEntered: false,
                                                    syncIdentifier: "F4C094AA-9EBE-4804-8F02-90C7B613BDEC",
                                                    syncVersion: 2,
                                                    device: device)
            let object = CachedGlucoseObject(context: cacheStore.managedObjectContext)
            object.create(from: newGlucoseSample, provenanceIdentifier: "06173C6A-4945-4139-A77D-E3ABC3221EA9", healthKitStorageDelay: .minutes(1))
            XCTAssertNil(object.uuid)
            XCTAssertEqual(object.provenanceIdentifier, "06173C6A-4945-4139-A77D-E3ABC3221EA9")
            XCTAssertEqual(object.syncIdentifier, "F4C094AA-9EBE-4804-8F02-90C7B613BDEC")
            XCTAssertEqual(object.primitiveSyncVersion, 2)
            XCTAssertEqual(object.value, quantity.doubleValue(for: .milligramsPerDeciliter))
            XCTAssertEqual(object.unitString, HKUnit.milligramsPerDeciliter.unitString)
            XCTAssertEqual(object.startDate, startDate)
            XCTAssertEqual(object.isDisplayOnly, true)
            XCTAssertEqual(object.wasUserEntered, false)
            XCTAssertEqual(object.condition, .belowRange)
            XCTAssertEqual(object.trend, .flat)
            XCTAssertEqual(object.trendRateUnit, HKUnit.milligramsPerDeciliterPerMinute.unitString)
            XCTAssertEqual(object.trendRateValue, 0.1)
            XCTAssertEqual(object.modificationCounter, 1)
            XCTAssertEqual(object.device, device)
            XCTAssertEqual(object.healthKitEligibleDate, startDate.addingTimeInterval(.minutes(1)))
        }
    }

    func testCreateFromQuantitySample() {
        cacheStore.managedObjectContext.performAndWait {
            let type = HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!
            let startDate = dateFormatter.date(from: "2020-02-03T04:05:06Z")!
            let quantity = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 123.4)
            let device = HKDevice(name: "NAME", manufacturer: "MANUFACTURER", model: "MODEL", hardwareVersion: "HARDWAREVERSION", firmwareVersion: "FIRMWAREVERSION", softwareVersion: "SOFTWAREVERSION", localIdentifier: "LOCALIDENTIFIER", udiDeviceIdentifier: "UDIDEVICEIDENTIFIER")
            let metadata: [String: Any] = [
                HKMetadataKeySyncIdentifier: "0B2353CD-7F98-4297-81E2-8D6FCDD02655",
                HKMetadataKeySyncVersion: 2,
                MetadataKeyGlucoseIsDisplayOnly: false,
                HKMetadataKeyWasUserEntered: true,
                MetadataKeyGlucoseCondition: "belowRange",
                MetadataKeyGlucoseTrend: "→",
                MetadataKeyGlucoseTrendRateUnit: HKUnit.milligramsPerDeciliterPerMinute.unitString,
                MetadataKeyGlucoseTrendRateValue: 0.1
            ]
            let quantitySample = HKQuantitySample(type: type, quantity: quantity, start: startDate, end: startDate, device: device, metadata: metadata)
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
            XCTAssertEqual(object.condition, .belowRange)
            XCTAssertEqual(object.trend, .flat)
            XCTAssertEqual(object.trendRateUnit, HKUnit.milligramsPerDeciliterPerMinute.unitString)
            XCTAssertEqual(object.trendRateValue, 0.1)
            XCTAssertEqual(object.modificationCounter, 1)
            XCTAssertEqual(object.device, device)
            XCTAssertEqual(object.healthKitEligibleDate, nil)
        }
    }
    
    func testToHKQuantitySample() {
        cacheStore.managedObjectContext.performAndWait {
            let type = HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!
            let startDate = dateFormatter.date(from: "2020-02-03T04:05:06Z")!
            let quantity = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 123.4)
            let device = HKDevice(name: "NAME", manufacturer: "MANUFACTURER", model: "MODEL", hardwareVersion: "HARDWAREVERSION", firmwareVersion: "FIRMWAREVERSION", softwareVersion: "SOFTWAREVERSION", localIdentifier: "LOCALIDENTIFIER", udiDeviceIdentifier: "UDIDEVICEIDENTIFIER")
            let metadata: [String: Any] = [
                HKMetadataKeySyncIdentifier: "0B2353CD-7F98-4297-81E2-8D6FCDD02655",
                HKMetadataKeySyncVersion: 2,
                MetadataKeyGlucoseIsDisplayOnly: true,
                HKMetadataKeyWasUserEntered: true,
                MetadataKeyGlucoseCondition: "belowRange",
                MetadataKeyGlucoseTrend: "→",
                MetadataKeyGlucoseTrendRateUnit: HKUnit.milligramsPerDeciliterPerMinute.unitString,
                MetadataKeyGlucoseTrendRateValue: 0.1
            ]
            let quantitySample = HKQuantitySample(type: type, quantity: quantity, start: startDate, end: startDate, device: device, metadata: metadata)
            let object = CachedGlucoseObject(context: cacheStore.managedObjectContext)
            object.create(from: quantitySample)
            XCTAssertEqual(quantitySample.quantity, object.quantitySample.quantity)
            XCTAssertEqual(quantitySample.quantityType, object.quantitySample.quantityType)
            XCTAssertEqual(quantitySample.condition, object.quantitySample.condition)
            XCTAssertEqual(quantitySample.trend, object.quantitySample.trend)
            XCTAssertEqual(quantitySample.trendRate, object.quantitySample.trendRate)
            XCTAssertEqual(quantitySample.provenanceIdentifier, object.quantitySample.provenanceIdentifier)
            XCTAssertEqual(quantitySample.absorptionTime, object.quantitySample.absorptionTime)
            XCTAssertEqual(quantitySample.automaticallyIssued, object.quantitySample.automaticallyIssued)
            XCTAssertEqual(quantitySample.count, object.quantitySample.count)
            XCTAssertEqual(quantitySample.createdByCurrentApp, object.quantitySample.createdByCurrentApp)
            XCTAssertEqual(quantitySample.hasLoopKitOrigin, object.quantitySample.hasLoopKitOrigin)
            XCTAssertEqual(quantitySample.isDisplayOnly, object.quantitySample.isDisplayOnly)
            XCTAssertEqual(quantitySample.manuallyEntered, object.quantitySample.manuallyEntered)
            XCTAssertEqual(quantitySample.wasUserEntered, object.quantitySample.wasUserEntered)
            XCTAssertEqual(quantitySample.syncVersion, object.quantitySample.syncVersion)
            XCTAssertEqual(quantitySample.syncIdentifier, object.quantitySample.syncIdentifier)
            XCTAssertEqual(quantitySample.startDate, object.quantitySample.startDate)
            XCTAssertEqual(quantitySample.endDate, object.quantitySample.endDate)
            XCTAssertNotEqual(quantitySample.uuid, object.quantitySample.uuid) // the UUIDs won't be the same...
            XCTAssertEqual(quantitySample.dose, object.quantitySample.dose)
            XCTAssertEqual(quantitySample.foodType, object.quantitySample.foodType)
            XCTAssertEqual(quantitySample.insulinType, object.quantitySample.insulinType)
            XCTAssertEqual(quantitySample.insulinDeliveryReason, object.quantitySample.insulinDeliveryReason)
            XCTAssertEqual(quantitySample.device, object.quantitySample.device)
        }
    }

    private let dateFormatter = ISO8601DateFormatter()
}
