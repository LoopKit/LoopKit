//
//  StoredGlucoseSampleTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 10/12/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
@testable import LoopKit

class StoredGlucoseSampleInitializerTests: XCTestCase {
    func testQuantitySampleInitializer() {
        let type = HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!
        let startDate = dateFormatter.date(from: "2020-01-02T03:04:05Z")!
        let quantity = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 123.4)
        let metadata: [String: Any] = [
            HKMetadataKeySyncIdentifier: "3A95BED9-2633-4D6A-9229-70B07521C561",
            HKMetadataKeySyncVersion: 2,
            MetadataKeyGlucoseIsDisplayOnly: true,
            HKMetadataKeyWasUserEntered: true
        ]
        let quantitySample = HKQuantitySample(type: type, quantity: quantity, start: startDate, end: startDate, metadata: metadata)
        let sample = StoredGlucoseSample(sample: quantitySample)
        XCTAssertNotNil(sample.uuid)
        XCTAssertEqual(sample.provenanceIdentifier, "")
        XCTAssertEqual(sample.syncIdentifier, "3A95BED9-2633-4D6A-9229-70B07521C561")
        XCTAssertEqual(sample.syncVersion, 2)
        XCTAssertEqual(sample.startDate, startDate)
        XCTAssertEqual(sample.quantity, quantity)
        XCTAssertEqual(sample.isDisplayOnly, true)
        XCTAssertEqual(sample.wasUserEntered, true)
    }

    func testFullInitializer() {
        let uuid = UUID()
        let startDate = dateFormatter.date(from: "2020-02-03T04:05:06Z")!
        let quantity = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 134.5)
        let trendRate = HKQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: 0.0)
        let device = HKDevice(name: "NAME", manufacturer: "MANUFACTURER", model: "MODEL", hardwareVersion: "HARDWAREVERSION", firmwareVersion: "FIRMWAREVERSION", softwareVersion: "SOFTWAREVERSION", localIdentifier: "LOCALIDENTIFIER", udiDeviceIdentifier: "UDIDEVICEIDENTIFIER")
        let sample = StoredGlucoseSample(uuid: uuid,
                                         provenanceIdentifier: "8A1333E7-79CB-413F-AB7A-5413F14D4531",
                                         syncIdentifier: "E7D34EED-CFEE-48FD-810F-5C8C41FACA83",
                                         syncVersion: 3,
                                         startDate: startDate,
                                         quantity: quantity,
                                         condition: .aboveRange,
                                         trend: .flat,
                                         trendRate: trendRate,
                                         isDisplayOnly: true,
                                         wasUserEntered: false,
                                         device: device,
                                         healthKitEligibleDate: startDate.addingTimeInterval(.hours(3)))
        XCTAssertEqual(sample.uuid, uuid)
        XCTAssertEqual(sample.provenanceIdentifier, "8A1333E7-79CB-413F-AB7A-5413F14D4531")
        XCTAssertEqual(sample.syncIdentifier, "E7D34EED-CFEE-48FD-810F-5C8C41FACA83")
        XCTAssertEqual(sample.syncVersion, 3)
        XCTAssertEqual(sample.startDate, startDate)
        XCTAssertEqual(sample.quantity, quantity)
        XCTAssertEqual(sample.condition, .aboveRange)
        XCTAssertEqual(sample.trend, .flat)
        XCTAssertEqual(sample.trendRate, trendRate)
        XCTAssertEqual(sample.isDisplayOnly, true)
        XCTAssertEqual(sample.wasUserEntered, false)
        XCTAssertEqual(sample.device, device)
        XCTAssertEqual(sample.healthKitEligibleDate, startDate.addingTimeInterval(.hours(3)))
    }

    func testFullInitializerOptional() {
        let startDate = dateFormatter.date(from: "2020-03-04T05:06:07Z")!
        let quantity = HKQuantity(unit: .millimolesPerLiter, doubleValue: 6.5)
        let sample = StoredGlucoseSample(uuid: nil,
                                         provenanceIdentifier: "95F800A3-A59D-4419-B8F2-611BED0962CF",
                                         syncIdentifier: nil,
                                         syncVersion: nil,
                                         startDate: startDate,
                                         quantity: quantity,
                                         condition: nil,
                                         trend: nil,
                                         trendRate: nil,
                                         isDisplayOnly: false,
                                         wasUserEntered: true,
                                         device: nil,
                                         healthKitEligibleDate: nil)
        XCTAssertNil(sample.uuid)
        XCTAssertEqual(sample.provenanceIdentifier, "95F800A3-A59D-4419-B8F2-611BED0962CF")
        XCTAssertNil(sample.syncIdentifier)
        XCTAssertNil(sample.syncVersion)
        XCTAssertEqual(sample.startDate, startDate)
        XCTAssertEqual(sample.quantity, quantity)
        XCTAssertNil(sample.condition)
        XCTAssertNil(sample.trend)
        XCTAssertNil(sample.trendRate)
        XCTAssertEqual(sample.isDisplayOnly, false)
        XCTAssertEqual(sample.wasUserEntered, true)
        XCTAssertNil(sample.device)
        XCTAssertNil(sample.healthKitEligibleDate)
    }

    private let dateFormatter = ISO8601DateFormatter()
}

class StoredGlucoseSampleManagedObjectInitializerTests: PersistenceControllerTestCase {
    func testManagedObjectInitializer() {
        cacheStore.managedObjectContext.performAndWait {
            let uuid = UUID()
            let startDate = dateFormatter.date(from: "2020-04-05T06:07:08Z")!
            let managedObject = CachedGlucoseObject(context: cacheStore.managedObjectContext)
            let device = HKDevice(name: "NAME", manufacturer: "MANUFACTURER", model: "MODEL", hardwareVersion: "HARDWAREVERSION", firmwareVersion: "FIRMWAREVERSION", softwareVersion: "SOFTWAREVERSION", localIdentifier: "LOCALIDENTIFIER", udiDeviceIdentifier: "UDIDEVICEIDENTIFIER")
            managedObject.uuid = uuid
            managedObject.provenanceIdentifier = "C198186D-F15C-4D0F-B8A1-83B28626DB3A"
            managedObject.syncIdentifier = "A313021C-4B11-448A-9266-B01321CA0BCC"
            managedObject.syncVersion = 4
            managedObject.value = 145.6
            managedObject.unitString = HKUnit.milligramsPerDeciliter.unitString
            managedObject.startDate = startDate
            managedObject.isDisplayOnly = true
            managedObject.wasUserEntered = true
            managedObject.device = device
            managedObject.condition = .aboveRange
            managedObject.trend = .downDownDown
            managedObject.trendRateUnit = HKUnit.milligramsPerDeciliterPerMinute.unitString
            managedObject.trendRateValue = -4.0
            managedObject.healthKitEligibleDate = startDate.addingTimeInterval(.hours(3))
            let sample = StoredGlucoseSample(managedObject: managedObject)
            XCTAssertEqual(sample.uuid, uuid)
            XCTAssertEqual(sample.provenanceIdentifier, "C198186D-F15C-4D0F-B8A1-83B28626DB3A")
            XCTAssertEqual(sample.syncIdentifier, "A313021C-4B11-448A-9266-B01321CA0BCC")
            XCTAssertEqual(sample.syncVersion, 4)
            XCTAssertEqual(sample.startDate, startDate)
            XCTAssertEqual(sample.quantity, HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 145.6))
            XCTAssertEqual(sample.isDisplayOnly, true)
            XCTAssertEqual(sample.wasUserEntered, true)
            XCTAssertEqual(sample.device, device)
            XCTAssertEqual(sample.condition, .aboveRange)
            XCTAssertEqual(sample.trend, .downDownDown)
            XCTAssertEqual(sample.trendRate, HKQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: -4.0))
            XCTAssertEqual(sample.healthKitEligibleDate, startDate.addingTimeInterval(.hours(3)))
        }
    }

    func testManagedObjectOptional() {
        cacheStore.managedObjectContext.performAndWait {
            let quantity = HKQuantity(unit: .millimolesPerLiter, doubleValue: 7.6)
            let startDate = dateFormatter.date(from: "2020-05-06T07:08:09Z")!
            let managedObject = CachedGlucoseObject(context: cacheStore.managedObjectContext)
            managedObject.provenanceIdentifier = "9A6AF580-7584-4FB1-90A2-ACCB96DF1D58"
            managedObject.value = quantity.doubleValue(for: .millimolesPerLiter)
            managedObject.unitString = HKUnit.millimolesPerLiter.unitString
            managedObject.startDate = startDate
            managedObject.isDisplayOnly = true
            managedObject.wasUserEntered = true
            let sample = StoredGlucoseSample(managedObject: managedObject)
            XCTAssertNil(sample.uuid)
            XCTAssertEqual(sample.provenanceIdentifier, "9A6AF580-7584-4FB1-90A2-ACCB96DF1D58")
            XCTAssertNil(sample.syncIdentifier)
            XCTAssertNil(sample.syncVersion)
            XCTAssertEqual(sample.startDate, startDate)
            XCTAssertEqual(sample.quantity, HKQuantity(unit: .millimolesPerLiter, doubleValue: 7.6))
            XCTAssertEqual(sample.isDisplayOnly, true)
            XCTAssertEqual(sample.wasUserEntered, true)
            XCTAssertNil(sample.device)
            XCTAssertNil(sample.condition)
            XCTAssertNil(sample.trend)
            XCTAssertNil(sample.trendRate)
            XCTAssertNil(sample.healthKitEligibleDate)
        }
    }

    private let dateFormatter = ISO8601DateFormatter()
}
