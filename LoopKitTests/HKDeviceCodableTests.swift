//
//  HKDeviceCodableTests.swift
//  LoopKitTests
//
//  Created by Rick Pasetto on 8/6/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import HealthKit
import XCTest
@testable import LoopKit

class HKDeviceCodableTests: XCTestCase {
    let device1 = HKDevice(name: "NAME1", manufacturer: "MANUFACTURER", model: "MODEL", hardwareVersion: "HARDWAREVERSION", firmwareVersion: "FIRMWAREVERSION", softwareVersion: "SOFTWAREVERSION", localIdentifier: "LOCALIDENTIFIER", udiDeviceIdentifier: "UDIDEVICEIDENTIFIER")
    let device1JSON = """
            {
              "firmwareVersion" : "FIRMWAREVERSION",
              "hardwareVersion" : "HARDWAREVERSION",
              "localIdentifier" : "LOCALIDENTIFIER",
              "manufacturer" : "MANUFACTURER",
              "model" : "MODEL",
              "name" : "NAME1",
              "softwareVersion" : "SOFTWAREVERSION",
              "udiDeviceIdentifier" : "UDIDEVICEIDENTIFIER"
            }
            """
    let device2 = HKDevice(name: "NAME2", manufacturer: "MANUFACTURER", model: "MODEL", hardwareVersion: "HARDWAREVERSION", firmwareVersion: "FIRMWAREVERSION", softwareVersion: "SOFTWAREVERSION", localIdentifier: "LOCALIDENTIFIER", udiDeviceIdentifier: "UDIDEVICEIDENTIFIER")
    let device2JSON = """
            {
              "firmwareVersion" : "FIRMWAREVERSION",
              "hardwareVersion" : "HARDWAREVERSION",
              "localIdentifier" : "LOCALIDENTIFIER",
              "manufacturer" : "MANUFACTURER",
              "model" : "MODEL",
              "name" : "NAME2",
              "softwareVersion" : "SOFTWAREVERSION",
              "udiDeviceIdentifier" : "UDIDEVICEIDENTIFIER"
            }
            """
    let device3 = HKDevice(name: "NAME3", manufacturer: nil, model: nil, hardwareVersion: nil, firmwareVersion: nil, softwareVersion: nil, localIdentifier: nil, udiDeviceIdentifier: nil)
    let device3JSON = """
            {
              "name" : "NAME3"
            }
            """

    let jsonEncoder: JSONEncoder = {
        let val = JSONEncoder()
        val.outputFormatting = [.prettyPrinted, .sortedKeys]
        return val
    }()
    let plistEncoder: PropertyListEncoder = {
        let val = PropertyListEncoder()
        val.outputFormat = .xml
        return val
    }()

    func testEncode() throws {
        XCTAssertEqual(device1JSON, String(data: try jsonEncoder.encode(device1), encoding: .utf8))
        XCTAssertEqual(device2JSON, String(data: try jsonEncoder.encode(device2), encoding: .utf8))
        XCTAssertEqual(device3JSON, String(data: try jsonEncoder.encode(device3), encoding: .utf8))
        XCTAssertNotEqual(device2JSON, String(data: try jsonEncoder.encode(device1), encoding: .utf8))
    }

    func testDecodeJSON() throws {
        XCTAssertEqual(device1, try HKDevice(from: device1JSON.data(using: .utf8)!))
        XCTAssertEqual(device2, try HKDevice(from: device2JSON.data(using: .utf8)!))
        XCTAssertEqual(device3, try HKDevice(from: device3JSON.data(using: .utf8)!))
    }
    
    func testDecodePropertyList() throws {
        XCTAssertEqual(device1, try HKDevice(from: plistEncoder.encode(device1)))
        XCTAssertEqual(device2, try HKDevice(from: plistEncoder.encode(device2)))
        XCTAssertEqual(device3, try HKDevice(from: plistEncoder.encode(device3)))
        XCTAssertNotEqual(device3, try HKDevice(from: plistEncoder.encode(device1)))
    }
    
    func testDecodeInvalidData() throws {
        XCTAssertThrowsError(try HKDevice(from: Data()))
    }
}
