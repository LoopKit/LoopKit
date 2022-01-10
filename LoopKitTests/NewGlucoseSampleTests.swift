//
//  NewGlucoseSampleTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 9/7/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
@testable import LoopKit

class NewGlucoseSampleTests: XCTestCase {
    func testQuantitySample() {
        let date = Date()
        let quantity = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 145.3)
        let trendRate = HKQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: 1.1)
        let device = HKDevice(name: "Device Name",
                              manufacturer: "Device Manufacturer",
                              model: "Device Model",
                              hardwareVersion: "Device Hardware Version",
                              firmwareVersion: "Device Firmware Version",
                              softwareVersion: "Device Software Version",
                              localIdentifier: "Device Local Identifier",
                              udiDeviceIdentifier: "Device UDI Device Identifier")
        let syncIdentifier = UUID().uuidString
        let newGlucoseSample = NewGlucoseSample(date: date,
                                                quantity: quantity,
                                                condition: .aboveRange,
                                                trend: .up,
                                                trendRate: trendRate,
                                                isDisplayOnly: false,
                                                wasUserEntered: true,
                                                syncIdentifier: syncIdentifier,
                                                syncVersion: 3,
                                                device: device)
        let quantitySample = newGlucoseSample.quantitySample
        XCTAssertEqual(quantitySample.quantityType, HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!)
        XCTAssertEqual(quantitySample.quantity, quantity)
        XCTAssertEqual(quantitySample.startDate, date)
        XCTAssertEqual(quantitySample.endDate, date)
        XCTAssertEqual(quantitySample.device, device)
        XCTAssertEqual(quantitySample.metadata?[HKMetadataKeySyncIdentifier] as? String, syncIdentifier)
        XCTAssertEqual(quantitySample.metadata?[HKMetadataKeySyncVersion] as? Int, 3)
        XCTAssertEqual(quantitySample.metadata?[MetadataKeyGlucoseCondition] as? String, "aboveRange")
        XCTAssertEqual(quantitySample.metadata?[MetadataKeyGlucoseTrend] as? String, GlucoseTrend.up.symbol)
        XCTAssertEqual(quantitySample.metadata?[MetadataKeyGlucoseTrendRateUnit] as? String, HKUnit.milligramsPerDeciliterPerMinute.unitString)
        XCTAssertEqual(quantitySample.metadata?[MetadataKeyGlucoseTrendRateValue] as? Double, 1.1)
        XCTAssertNil(quantitySample.metadata?[MetadataKeyGlucoseIsDisplayOnly])
        XCTAssertEqual(quantitySample.metadata?[HKMetadataKeyWasUserEntered] as? Bool, true)
    }
}
