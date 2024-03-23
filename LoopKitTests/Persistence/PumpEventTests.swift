//
//  PumpEventTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 8/26/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit

class PumpEventEncodableTests: PersistenceControllerTestCase {
    func testEncodable() throws {
        cacheStore.managedObjectContext.performAndWait {
            let pumpEvent = PumpEvent(context: cacheStore.managedObjectContext)
            pumpEvent.createdAt = dateFormatter.date(from: "2020-05-14T22:33:48Z")!
            pumpEvent.date = dateFormatter.date(from: "2020-05-14T22:38:14Z")!
            pumpEvent.doseType = .tempBasal
            pumpEvent.duration = .minutes(30)
            pumpEvent.type = .tempBasal
            pumpEvent.unit = .unitsPerHour
            pumpEvent.uploaded = false
            pumpEvent.value = 1.23
            pumpEvent.deliveredUnits = 0.56
            pumpEvent.mutable = true
            pumpEvent.raw = Data(base64Encoded: "MTIzNDU2Nzg5MA==")!
            pumpEvent.title = "This is the title"
            pumpEvent.insulinType = .fiasp
            pumpEvent.automatic = false
            pumpEvent.alarmType = .other("An Alarm")
            pumpEvent.modificationCounter = 123
            pumpEvent.wasProgrammedByPumpUI = true
            let data = try! encoder.encode(pumpEvent)
            XCTAssertEqual(String(data: data, encoding: .utf8), """
{
  "alarmType" : "An Alarm",
  "automatic" : false,
  "createdAt" : "2020-05-14T22:33:48Z",
  "date" : "2020-05-14T22:38:14Z",
  "deliveredUnits" : 0.56,
  "doseType" : "tempBasal",
  "duration" : 1800,
  "insulinType" : 3,
  "modificationCounter" : 123,
  "mutable" : true,
  "raw" : "MTIzNDU2Nzg5MA==",
  "title" : "This is the title",
  "type" : "TempBasal",
  "unit" : "U/hour",
  "uploaded" : false,
  "value" : 1.23,
  "wasProgrammedByPumpUI" : true
}
"""
            )
        }
    }

    func testEncodableOptional() throws {
        cacheStore.managedObjectContext.performAndWait {
            let pumpEvent = PumpEvent(context: cacheStore.managedObjectContext)
            pumpEvent.createdAt = dateFormatter.date(from: "2020-05-13T22:33:48Z")!
            pumpEvent.date = dateFormatter.date(from: "2020-05-13T22:38:14Z")!
            pumpEvent.duration = .minutes(60)
            pumpEvent.uploaded = true
            pumpEvent.mutable = false
            pumpEvent.modificationCounter = 234
            pumpEvent.wasProgrammedByPumpUI = true

            let data = try! encoder.encode(pumpEvent)
            XCTAssertEqual(String(data: data, encoding: .utf8), """
{
  "createdAt" : "2020-05-13T22:33:48Z",
  "date" : "2020-05-13T22:38:14Z",
  "duration" : 3600,
  "insulinType" : 0,
  "modificationCounter" : 234,
  "mutable" : false,
  "uploaded" : true,
  "wasProgrammedByPumpUI" : true
}
"""
            )
        }
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
