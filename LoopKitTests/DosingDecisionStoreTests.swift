//
//  DosingDecisionStoreTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 1/6/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
@testable import LoopKit

class DosingDecisionStorePersistenceTests: PersistenceControllerTestCase, DosingDecisionStoreDelegate {

    var dosingDecisionStore: DosingDecisionStore!

    override func setUp() {
        super.setUp()

        dosingDecisionStoreHasUpdatedDosingDecisionDataHandler = nil
        dosingDecisionStore = DosingDecisionStore(store: cacheStore, expireAfter: .hours(1))
        dosingDecisionStore.delegate = self
    }

    override func tearDown() {
        dosingDecisionStore.delegate = nil
        dosingDecisionStore = nil
        dosingDecisionStoreHasUpdatedDosingDecisionDataHandler = nil

        super.tearDown()
    }

    // MARK: - DosingDecisionStoreDelegate

    var dosingDecisionStoreHasUpdatedDosingDecisionDataHandler: ((_ : DosingDecisionStore) -> Void)?

    func dosingDecisionStoreHasUpdatedDosingDecisionData(_ dosingDecisionStore: DosingDecisionStore) {
        dosingDecisionStoreHasUpdatedDosingDecisionDataHandler?(dosingDecisionStore)
    }

    // MARK: -

    func testStoreDosingDecision() {
        let storeDosingDecisionHandler = expectation(description: "Store dosing decision handler")
        let storeDosingDecisionCompletion = expectation(description: "Store dosing decision completion")

        var handlerInvocation = 0

        dosingDecisionStoreHasUpdatedDosingDecisionDataHandler = { dosingDecisionStore in
            handlerInvocation += 1

            switch handlerInvocation {
            case 1:
                storeDosingDecisionHandler.fulfill()
            default:
                XCTFail("Unexpected handler invocation")
            }
        }

        dosingDecisionStore.storeDosingDecision(StoredDosingDecision(reason: "test")) {
            storeDosingDecisionCompletion.fulfill()
        }

        wait(for: [storeDosingDecisionHandler, storeDosingDecisionCompletion], timeout: 2, enforceOrder: true)
    }

    func testStoreDosingDecisionMultiple() {
        let storeDosingDecisionHandler1 = expectation(description: "Store dosing decision handler 1")
        let storeDosingDecisionHandler2 = expectation(description: "Store dosing decision handler 2")
        let storeDosingDecisionCompletion1 = expectation(description: "Store dosing decision completion 1")
        let storeDosingDecisionCompletion2 = expectation(description: "Store dosing decision completion 2")

        var handlerInvocation = 0

        dosingDecisionStoreHasUpdatedDosingDecisionDataHandler = { dosingDecisionStore in
            handlerInvocation += 1

            switch handlerInvocation {
            case 1:
                storeDosingDecisionHandler1.fulfill()
            case 2:
                storeDosingDecisionHandler2.fulfill()
            default:
                XCTFail("Unexpected handler invocation")
            }
        }

        dosingDecisionStore.storeDosingDecision(StoredDosingDecision(reason: "test")) {
            storeDosingDecisionCompletion1.fulfill()
        }

        dosingDecisionStore.storeDosingDecision(StoredDosingDecision(reason: "test")) {
            storeDosingDecisionCompletion2.fulfill()
        }

        wait(for: [storeDosingDecisionHandler1, storeDosingDecisionCompletion1, storeDosingDecisionHandler2, storeDosingDecisionCompletion2], timeout: 2, enforceOrder: true)
    }

    func testDosingDecisionObjectEncodable() throws {
        cacheStore.managedObjectContext.performAndWait {
            do {
                let object = DosingDecisionObject(context: cacheStore.managedObjectContext)
                object.data = try PropertyListEncoder().encode(StoredDosingDecision.test)
                object.date = dateFormatter.date(from: "2100-01-02T03:03:00Z")!
                object.modificationCounter = 123
                try assertDosingDecisionObjectEncodable(object, encodesJSON: """
{
  "data" : {
    "automaticDoseRecommendation" : {
      "basalAdjustment" : {
        "duration" : 1800,
        "unitsPerHour" : 0.75
      },
      "bolusUnits" : 1.25
    },
    "carbEntry" : {
      "absorptionTime" : 18000,
      "createdByCurrentApp" : true,
      "foodType" : "Pizza",
      "provenanceIdentifier" : "com.loopkit.loop",
      "quantity" : 29,
      "startDate" : "2020-01-02T03:00:23Z",
      "syncIdentifier" : "2B03D96C-6F5D-4140-99CD-80C3E64D6010",
      "syncVersion" : 2,
      "userCreatedDate" : "2020-05-14T22:06:12Z",
      "userUpdatedDate" : "2020-05-14T22:07:32Z",
      "uuid" : "135CDABE-9343-7242-4233-1020384789AE"
    },
    "carbsOnBoard" : {
      "endDate" : "2020-05-14T23:18:41Z",
      "quantity" : 45.5,
      "quantityUnit" : "g",
      "startDate" : "2020-05-14T22:48:41Z"
    },
    "cgmManagerStatus" : {
      "device" : {
        "firmwareVersion" : "CGM Firmware Version",
        "hardwareVersion" : "CGM Hardware Version",
        "localIdentifier" : "CGM Local Identifier",
        "manufacturer" : "CGM Manufacturer",
        "model" : "CGM Model",
        "name" : "CGM Name",
        "softwareVersion" : "CGM Software Version",
        "udiDeviceIdentifier" : "CGM UDI Device Identifier"
      },
      "hasValidSensorSession" : true,
      "lastCommunicationDate" : "2020-05-14T22:07:01Z"
    },
    "controllerStatus" : {
      "batteryLevel" : 0.5,
      "batteryState" : "charging"
    },
    "controllerTimeZone" : {
      "identifier" : "America/Los_Angeles"
    },
    "date" : "2020-05-14T22:38:14Z",
    "errors" : [
      {
        "id" : "alpha"
      },
      {
        "details" : {
          "size" : "tiny"
        },
        "id" : "bravo"
      }
    ],
    "glucoseTargetRangeSchedule" : {
      "override" : {
        "end" : "2020-05-14T23:12:17Z",
        "start" : "2020-05-14T21:12:17Z",
        "value" : {
          "maxValue" : 115,
          "minValue" : 105
        }
      },
      "rangeSchedule" : {
        "unit" : "mg/dL",
        "valueSchedule" : {
          "items" : [
            {
              "startTime" : 0,
              "value" : {
                "maxValue" : 110,
                "minValue" : 100
              }
            },
            {
              "startTime" : 25200,
              "value" : {
                "maxValue" : 100,
                "minValue" : 90
              }
            },
            {
              "startTime" : 75600,
              "value" : {
                "maxValue" : 120,
                "minValue" : 110
              }
            }
          ],
          "referenceTimeInterval" : 0,
          "repeatInterval" : 86400,
          "timeZone" : {
            "identifier" : "GMT-0700"
          }
        }
      }
    },
    "historicalGlucose" : [
      {
        "quantity" : 117.3,
        "quantityUnit" : "mg/dL",
        "startDate" : "2020-05-14T22:29:15Z"
      },
      {
        "quantity" : 119.5,
        "quantityUnit" : "mg/dL",
        "startDate" : "2020-05-14T22:33:15Z"
      },
      {
        "quantity" : 121.8,
        "quantityUnit" : "mg/dL",
        "startDate" : "2020-05-14T22:38:15Z"
      }
    ],
    "insulinOnBoard" : {
      "startDate" : "2020-05-14T22:38:26Z",
      "value" : 1.5
    },
    "lastReservoirValue" : {
      "startDate" : "2020-05-14T22:07:19Z",
      "unitVolume" : 113.3
    },
    "manualBolusRecommendation" : {
      "date" : "2020-05-14T22:38:16Z",
      "recommendation" : {
        "amount" : 1.2,
        "notice" : {
          "predictedGlucoseBelowTarget" : {
            "minGlucose" : {
              "endDate" : "2020-05-14T23:03:15Z",
              "quantity" : 75.5,
              "quantityUnit" : "mg/dL",
              "startDate" : "2020-05-14T23:03:15Z"
            }
          }
        },
        "pendingInsulin" : 0.75
      }
    },
    "manualBolusRequested" : 0.80000000000000004,
    "manualGlucoseSample" : {
      "condition" : "aboveRange",
      "device" : {
        "firmwareVersion" : "Device Firmware Version",
        "hardwareVersion" : "Device Hardware Version",
        "localIdentifier" : "Device Local Identifier",
        "manufacturer" : "Device Manufacturer",
        "model" : "Device Model",
        "name" : "Device Name",
        "softwareVersion" : "Device Software Version",
        "udiDeviceIdentifier" : "Device UDI Device Identifier"
      },
      "isDisplayOnly" : false,
      "provenanceIdentifier" : "com.loopkit.loop",
      "quantity" : 400,
      "startDate" : "2020-05-14T22:09:00Z",
      "syncIdentifier" : "d3876f59-adb3-4a4f-8b29-315cda22062e",
      "syncVersion" : 1,
      "trend" : 7,
      "trendRate" : -10.199999999999999,
      "uuid" : "DA0CED44-E4F1-49C4-BAF8-6EFA6D75525F",
      "wasUserEntered" : true
    },
    "originalCarbEntry" : {
      "absorptionTime" : 18000,
      "createdByCurrentApp" : true,
      "foodType" : "Pizza",
      "provenanceIdentifier" : "com.loopkit.loop",
      "quantity" : 19,
      "startDate" : "2020-01-02T03:00:23Z",
      "syncIdentifier" : "2B03D96C-6F5D-4140-99CD-80C3E64D6010",
      "syncVersion" : 1,
      "userCreatedDate" : "2020-05-14T22:06:12Z",
      "uuid" : "18CF3948-0B3D-4B12-8BFE-14986B0E6784"
    },
    "predictedGlucose" : [
      {
        "quantity" : 123.3,
        "quantityUnit" : "mg/dL",
        "startDate" : "2020-05-14T22:43:15Z"
      },
      {
        "quantity" : 125.5,
        "quantityUnit" : "mg/dL",
        "startDate" : "2020-05-14T22:48:15Z"
      },
      {
        "quantity" : 127.8,
        "quantityUnit" : "mg/dL",
        "startDate" : "2020-05-14T22:53:15Z"
      }
    ],
    "pumpManagerStatus" : {
      "basalDeliveryState" : "initiatingTempBasal",
      "bolusState" : "noBolus",
      "deliveryIsUncertain" : false,
      "device" : {
        "firmwareVersion" : "Pump Firmware Version",
        "hardwareVersion" : "Pump Hardware Version",
        "localIdentifier" : "Pump Local Identifier",
        "manufacturer" : "Pump Manufacturer",
        "model" : "Pump Model",
        "name" : "Pump Name",
        "softwareVersion" : "Pump Software Version",
        "udiDeviceIdentifier" : "Pump UDI Device Identifier"
      },
      "insulinType" : 0,
      "pumpBatteryChargeRemaining" : 0.75,
      "timeZone" : {
        "identifier" : "GMT-0700"
      }
    },
    "reason" : "test",
    "scheduleOverride" : {
      "actualEnd" : {
        "type" : "natural"
      },
      "context" : "preMeal",
      "duration" : {
        "finite" : {
          "duration" : 3600
        }
      },
      "enactTrigger" : "local",
      "settings" : {
        "insulinNeedsScaleFactor" : 1.5,
        "targetRangeInMgdl" : {
          "maxValue" : 90,
          "minValue" : 80
        }
      },
      "startDate" : "2020-05-14T22:22:01Z",
      "syncIdentifier" : "394818CF-99CD-4B12-99CD-0E678414986B"
    },
    "settings" : {
      "syncIdentifier" : "2B03D96C-99CD-4140-99CD-80C3E64D6011"
    },
    "syncIdentifier" : "2A67A303-5203-4CB8-8263-79498265368E",
    "warnings" : [
      {
        "id" : "one"
      },
      {
        "details" : {
          "size" : "small"
        },
        "id" : "two"
      }
    ]
  },
  "date" : "2100-01-02T03:03:00Z",
  "modificationCounter" : 123
}
"""
                )
            } catch let error {
                XCTFail("Unexpected failure: \(error)")
            }
        }
    }

    private func assertDosingDecisionObjectEncodable(_ original: DosingDecisionObject, encodesJSON string: String) throws {
        let data = try encoder.encode(original)
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
    }

    private let dateFormatter = ISO8601DateFormatter()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

class DosingDecisionStoreQueryAnchorTests: XCTestCase {

    var rawValue: DosingDecisionStore.QueryAnchor.RawValue = [
        "modificationCounter": Int64(123)
    ]

    func testInitializerDefault() {
        let queryAnchor = DosingDecisionStore.QueryAnchor()
        XCTAssertEqual(queryAnchor.modificationCounter, 0)
    }

    func testInitializerRawValue() {
        let queryAnchor = DosingDecisionStore.QueryAnchor(rawValue: rawValue)
        XCTAssertNotNil(queryAnchor)
        XCTAssertEqual(queryAnchor?.modificationCounter, 123)
    }

    func testInitializerRawValueMissingModificationCounter() {
        rawValue["modificationCounter"] = nil
        XCTAssertNil(DosingDecisionStore.QueryAnchor(rawValue: rawValue))
    }

    func testInitializerRawValueInvalidModificationCounter() {
        rawValue["modificationCounter"] = "123"
        XCTAssertNil(DosingDecisionStore.QueryAnchor(rawValue: rawValue))
    }

    func testRawValueWithDefault() {
        let rawValue = DosingDecisionStore.QueryAnchor().rawValue
        XCTAssertEqual(rawValue.count, 1)
        XCTAssertEqual(rawValue["modificationCounter"] as? Int64, Int64(0))
    }

    func testRawValueWithNonDefault() {
        var queryAnchor = DosingDecisionStore.QueryAnchor()
        queryAnchor.modificationCounter = 123
        let rawValue = queryAnchor.rawValue
        XCTAssertEqual(rawValue.count, 1)
        XCTAssertEqual(rawValue["modificationCounter"] as? Int64, Int64(123))
    }

}

class DosingDecisionStoreQueryTests: PersistenceControllerTestCase {

    var dosingDecisionStore: DosingDecisionStore!
    var completion: XCTestExpectation!
    var queryAnchor: DosingDecisionStore.QueryAnchor!
    var limit: Int!

    override func setUp() {
        super.setUp()

        dosingDecisionStore = DosingDecisionStore(store: cacheStore, expireAfter: .hours(1))
        completion = expectation(description: "Completion")
        queryAnchor = DosingDecisionStore.QueryAnchor()
        limit = Int.max
    }

    override func tearDown() {
        limit = nil
        queryAnchor = nil
        completion = nil
        dosingDecisionStore = nil

        super.tearDown()
    }

    // MARK: -

    func testEmptyWithDefaultQueryAnchor() {
        dosingDecisionStore.executeDosingDecisionQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 0)
                XCTAssertEqual(data.count, 0)
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testEmptyWithMissingQueryAnchor() {
        queryAnchor = nil

        dosingDecisionStore.executeDosingDecisionQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 0)
                XCTAssertEqual(data.count, 0)
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testEmptyWithNonDefaultQueryAnchor() {
        queryAnchor.modificationCounter = 1

        dosingDecisionStore.executeDosingDecisionQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 1)
                XCTAssertEqual(data.count, 0)
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testDataWithUnusedQueryAnchor() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]

        addData(withSyncIdentifiers: syncIdentifiers)

        dosingDecisionStore.executeDosingDecisionQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 3)
                XCTAssertEqual(data.count, 3)
                for (index, syncIdentifier) in syncIdentifiers.enumerated() {
                    XCTAssertEqual(data[index].syncIdentifier, syncIdentifier)
                }
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testDataWithStaleQueryAnchor() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]

        addData(withSyncIdentifiers: syncIdentifiers)

        queryAnchor.modificationCounter = 2

        dosingDecisionStore.executeDosingDecisionQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 3)
                XCTAssertEqual(data.count, 1)
                XCTAssertEqual(data[0].syncIdentifier, syncIdentifiers[2])
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testDataWithCurrentQueryAnchor() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]

        addData(withSyncIdentifiers: syncIdentifiers)

        queryAnchor.modificationCounter = 3

        dosingDecisionStore.executeDosingDecisionQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 3)
                XCTAssertEqual(data.count, 0)
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testDataWithLimitZero() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]

        addData(withSyncIdentifiers: syncIdentifiers)

        limit = 0

        dosingDecisionStore.executeDosingDecisionQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 0)
                XCTAssertEqual(data.count, 0)
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testDataWithLimitCoveredByData() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]

        addData(withSyncIdentifiers: syncIdentifiers)

        limit = 2

        dosingDecisionStore.executeDosingDecisionQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 2)
                XCTAssertEqual(data.count, 2)
                XCTAssertEqual(data[0].syncIdentifier, syncIdentifiers[0])
                XCTAssertEqual(data[1].syncIdentifier, syncIdentifiers[1])
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    private func addData(withSyncIdentifiers syncIdentifiers: [UUID]) {
        let semaphore = DispatchSemaphore(value: 0)
        for syncIdentifier in syncIdentifiers {
            self.dosingDecisionStore.storeDosingDecision(StoredDosingDecision(reason: "test", syncIdentifier: syncIdentifier)) { semaphore.signal() }
        }
        for _ in syncIdentifiers { semaphore.wait() }
    }

    private func generateSyncIdentifier() -> UUID { UUID() }
}

class DosingDecisionStoreCriticalEventLogTests: PersistenceControllerTestCase {
    var dosingDecisionStore: DosingDecisionStore!
    var outputStream: MockOutputStream!
    var progress: Progress!

    override func setUp() {
        super.setUp()

        let dosingDecisions = [StoredDosingDecision(date: dateFormatter.date(from: "2100-01-02T03:08:00Z")!, controllerTimeZone: TimeZone(identifier: "America/Los_Angeles")!, reason: "test", syncIdentifier: UUID(uuidString: "18CF3948-0B3D-4B12-8BFE-14986B0E6784")!),
                               StoredDosingDecision(date: dateFormatter.date(from: "2100-01-02T03:10:00Z")!, controllerTimeZone: TimeZone(identifier: "America/Los_Angeles")!, reason: "test", syncIdentifier: UUID(uuidString: "C86DEB61-68E9-464E-9DD5-96A9CB445FD3")!),
                               StoredDosingDecision(date: dateFormatter.date(from: "2100-01-02T03:04:00Z")!, controllerTimeZone: TimeZone(identifier: "America/Los_Angeles")!, reason: "test", syncIdentifier: UUID(uuidString: "2B03D96C-6F5D-4140-99CD-80C3E64D6010")!),
                               StoredDosingDecision(date: dateFormatter.date(from: "2100-01-02T03:06:00Z")!, controllerTimeZone: TimeZone(identifier: "America/Los_Angeles")!, reason: "test", syncIdentifier: UUID(uuidString: "FF1C4F01-3558-4FB2-957E-FA1522C4735E")!),
                               StoredDosingDecision(date: dateFormatter.date(from: "2100-01-02T03:02:00Z")!, controllerTimeZone: TimeZone(identifier: "America/Los_Angeles")!, reason: "test", syncIdentifier: UUID(uuidString: "71B699D7-0E8F-4B13-B7A1-E7751EB78E74")!)]

        dosingDecisionStore = DosingDecisionStore(store: cacheStore, expireAfter: .hours(1))

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        dosingDecisionStore.addStoredDosingDecisions(dosingDecisions: dosingDecisions) { error in
            XCTAssertNil(error)
            dispatchGroup.leave()
        }
        dispatchGroup.wait()

        outputStream = MockOutputStream()
        progress = Progress()
    }

    override func tearDown() {
        dosingDecisionStore = nil
        
        super.tearDown()
    }

    func testExportProgressTotalUnitCount() {
        switch dosingDecisionStore.exportProgressTotalUnitCount(startDate: dateFormatter.date(from: "2100-01-02T03:03:00Z")!,
                                                                endDate: dateFormatter.date(from: "2100-01-02T03:09:00Z")!) {
        case .failure(let error):
            XCTFail("Unexpected failure: \(error)")
        case .success(let progressTotalUnitCount):
            XCTAssertEqual(progressTotalUnitCount, 3 * 33)
        }
    }

    func testExportProgressTotalUnitCountEmpty() {
        switch dosingDecisionStore.exportProgressTotalUnitCount(startDate: dateFormatter.date(from: "2100-01-02T03:00:00Z")!,
                                                                endDate: dateFormatter.date(from: "2100-01-02T03:01:00Z")!) {
        case .failure(let error):
            XCTFail("Unexpected failure: \(error)")
        case .success(let progressTotalUnitCount):
            XCTAssertEqual(progressTotalUnitCount, 0)
        }
    }

    func testExport() {
        XCTAssertNil(dosingDecisionStore.export(startDate: dateFormatter.date(from: "2100-01-02T03:03:00Z")!,
                                                endDate: dateFormatter.date(from: "2100-01-02T03:09:00Z")!,
                                                to: outputStream,
                                                progress: progress))
        XCTAssertEqual(outputStream.string, """
[
{"data":{"controllerTimeZone":{"identifier":"America/Los_Angeles"},"date":"2100-01-02T03:08:00.000Z","reason":"test","syncIdentifier":"18CF3948-0B3D-4B12-8BFE-14986B0E6784"},"date":"2100-01-02T03:08:00.000Z","modificationCounter":1},
{"data":{"controllerTimeZone":{"identifier":"America/Los_Angeles"},"date":"2100-01-02T03:04:00.000Z","reason":"test","syncIdentifier":"2B03D96C-6F5D-4140-99CD-80C3E64D6010"},"date":"2100-01-02T03:04:00.000Z","modificationCounter":3},
{"data":{"controllerTimeZone":{"identifier":"America/Los_Angeles"},"date":"2100-01-02T03:06:00.000Z","reason":"test","syncIdentifier":"FF1C4F01-3558-4FB2-957E-FA1522C4735E"},"date":"2100-01-02T03:06:00.000Z","modificationCounter":4}
]
"""
        )
        XCTAssertEqual(progress.completedUnitCount, 3 * 33)
    }

    func testExportEmpty() {
        XCTAssertNil(dosingDecisionStore.export(startDate: dateFormatter.date(from: "2100-01-02T03:00:00Z")!,
                                                endDate: dateFormatter.date(from: "2100-01-02T03:01:00Z")!,
                                                to: outputStream,
                                                progress: progress))
        XCTAssertEqual(outputStream.string, "[]")
        XCTAssertEqual(progress.completedUnitCount, 0)
    }

    func testExportCancelled() {
        progress.cancel()
        XCTAssertEqual(dosingDecisionStore.export(startDate: dateFormatter.date(from: "2100-01-02T03:03:00Z")!,
                                                  endDate: dateFormatter.date(from: "2100-01-02T03:09:00Z")!,
                                                  to: outputStream,
                                                  progress: progress) as? CriticalEventLogError, CriticalEventLogError.cancelled)
    }

    private let dateFormatter = ISO8601DateFormatter()
}

class StoredDosingDecisionCodableTests: XCTestCase {
    func testCodable() throws {
        try assertStoredDosingDecisionCodable(StoredDosingDecision.test, encodesJSON: """
{
  "automaticDoseRecommendation" : {
    "basalAdjustment" : {
      "duration" : 1800,
      "unitsPerHour" : 0.75
    },
    "bolusUnits" : 1.25
  },
  "carbEntry" : {
    "absorptionTime" : 18000,
    "createdByCurrentApp" : true,
    "foodType" : "Pizza",
    "provenanceIdentifier" : "com.loopkit.loop",
    "quantity" : 29,
    "startDate" : "2020-01-02T03:00:23Z",
    "syncIdentifier" : "2B03D96C-6F5D-4140-99CD-80C3E64D6010",
    "syncVersion" : 2,
    "userCreatedDate" : "2020-05-14T22:06:12Z",
    "userUpdatedDate" : "2020-05-14T22:07:32Z",
    "uuid" : "135CDABE-9343-7242-4233-1020384789AE"
  },
  "carbsOnBoard" : {
    "endDate" : "2020-05-14T23:18:41Z",
    "quantity" : 45.5,
    "quantityUnit" : "g",
    "startDate" : "2020-05-14T22:48:41Z"
  },
  "cgmManagerStatus" : {
    "device" : {
      "firmwareVersion" : "CGM Firmware Version",
      "hardwareVersion" : "CGM Hardware Version",
      "localIdentifier" : "CGM Local Identifier",
      "manufacturer" : "CGM Manufacturer",
      "model" : "CGM Model",
      "name" : "CGM Name",
      "softwareVersion" : "CGM Software Version",
      "udiDeviceIdentifier" : "CGM UDI Device Identifier"
    },
    "hasValidSensorSession" : true,
    "lastCommunicationDate" : "2020-05-14T22:07:01Z"
  },
  "controllerStatus" : {
    "batteryLevel" : 0.5,
    "batteryState" : "charging"
  },
  "controllerTimeZone" : {
    "identifier" : "America/Los_Angeles"
  },
  "date" : "2020-05-14T22:38:14Z",
  "errors" : [
    {
      "id" : "alpha"
    },
    {
      "details" : {
        "size" : "tiny"
      },
      "id" : "bravo"
    }
  ],
  "glucoseTargetRangeSchedule" : {
    "override" : {
      "end" : "2020-05-14T23:12:17Z",
      "start" : "2020-05-14T21:12:17Z",
      "value" : {
        "maxValue" : 115,
        "minValue" : 105
      }
    },
    "rangeSchedule" : {
      "unit" : "mg/dL",
      "valueSchedule" : {
        "items" : [
          {
            "startTime" : 0,
            "value" : {
              "maxValue" : 110,
              "minValue" : 100
            }
          },
          {
            "startTime" : 25200,
            "value" : {
              "maxValue" : 100,
              "minValue" : 90
            }
          },
          {
            "startTime" : 75600,
            "value" : {
              "maxValue" : 120,
              "minValue" : 110
            }
          }
        ],
        "referenceTimeInterval" : 0,
        "repeatInterval" : 86400,
        "timeZone" : {
          "identifier" : "GMT-0700"
        }
      }
    }
  },
  "historicalGlucose" : [
    {
      "quantity" : 117.3,
      "quantityUnit" : "mg/dL",
      "startDate" : "2020-05-14T22:29:15Z"
    },
    {
      "quantity" : 119.5,
      "quantityUnit" : "mg/dL",
      "startDate" : "2020-05-14T22:33:15Z"
    },
    {
      "quantity" : 121.8,
      "quantityUnit" : "mg/dL",
      "startDate" : "2020-05-14T22:38:15Z"
    }
  ],
  "insulinOnBoard" : {
    "startDate" : "2020-05-14T22:38:26Z",
    "value" : 1.5
  },
  "lastReservoirValue" : {
    "startDate" : "2020-05-14T22:07:19Z",
    "unitVolume" : 113.3
  },
  "manualBolusRecommendation" : {
    "date" : "2020-05-14T22:38:16Z",
    "recommendation" : {
      "amount" : 1.2,
      "notice" : {
        "predictedGlucoseBelowTarget" : {
          "minGlucose" : {
            "endDate" : "2020-05-14T23:03:15Z",
            "quantity" : 75.5,
            "quantityUnit" : "mg/dL",
            "startDate" : "2020-05-14T23:03:15Z"
          }
        }
      },
      "pendingInsulin" : 0.75
    }
  },
  "manualBolusRequested" : 0.80000000000000004,
  "manualGlucoseSample" : {
    "condition" : "aboveRange",
    "device" : {
      "firmwareVersion" : "Device Firmware Version",
      "hardwareVersion" : "Device Hardware Version",
      "localIdentifier" : "Device Local Identifier",
      "manufacturer" : "Device Manufacturer",
      "model" : "Device Model",
      "name" : "Device Name",
      "softwareVersion" : "Device Software Version",
      "udiDeviceIdentifier" : "Device UDI Device Identifier"
    },
    "isDisplayOnly" : false,
    "provenanceIdentifier" : "com.loopkit.loop",
    "quantity" : 400,
    "startDate" : "2020-05-14T22:09:00Z",
    "syncIdentifier" : "d3876f59-adb3-4a4f-8b29-315cda22062e",
    "syncVersion" : 1,
    "trend" : 7,
    "trendRate" : -10.199999999999999,
    "uuid" : "DA0CED44-E4F1-49C4-BAF8-6EFA6D75525F",
    "wasUserEntered" : true
  },
  "originalCarbEntry" : {
    "absorptionTime" : 18000,
    "createdByCurrentApp" : true,
    "foodType" : "Pizza",
    "provenanceIdentifier" : "com.loopkit.loop",
    "quantity" : 19,
    "startDate" : "2020-01-02T03:00:23Z",
    "syncIdentifier" : "2B03D96C-6F5D-4140-99CD-80C3E64D6010",
    "syncVersion" : 1,
    "userCreatedDate" : "2020-05-14T22:06:12Z",
    "uuid" : "18CF3948-0B3D-4B12-8BFE-14986B0E6784"
  },
  "predictedGlucose" : [
    {
      "quantity" : 123.3,
      "quantityUnit" : "mg/dL",
      "startDate" : "2020-05-14T22:43:15Z"
    },
    {
      "quantity" : 125.5,
      "quantityUnit" : "mg/dL",
      "startDate" : "2020-05-14T22:48:15Z"
    },
    {
      "quantity" : 127.8,
      "quantityUnit" : "mg/dL",
      "startDate" : "2020-05-14T22:53:15Z"
    }
  ],
  "pumpManagerStatus" : {
    "basalDeliveryState" : "initiatingTempBasal",
    "bolusState" : "noBolus",
    "deliveryIsUncertain" : false,
    "device" : {
      "firmwareVersion" : "Pump Firmware Version",
      "hardwareVersion" : "Pump Hardware Version",
      "localIdentifier" : "Pump Local Identifier",
      "manufacturer" : "Pump Manufacturer",
      "model" : "Pump Model",
      "name" : "Pump Name",
      "softwareVersion" : "Pump Software Version",
      "udiDeviceIdentifier" : "Pump UDI Device Identifier"
    },
    "insulinType" : 0,
    "pumpBatteryChargeRemaining" : 0.75,
    "timeZone" : {
      "identifier" : "GMT-0700"
    }
  },
  "reason" : "test",
  "scheduleOverride" : {
    "actualEnd" : {
      "type" : "natural"
    },
    "context" : "preMeal",
    "duration" : {
      "finite" : {
        "duration" : 3600
      }
    },
    "enactTrigger" : "local",
    "settings" : {
      "insulinNeedsScaleFactor" : 1.5,
      "targetRangeInMgdl" : {
        "maxValue" : 90,
        "minValue" : 80
      }
    },
    "startDate" : "2020-05-14T22:22:01Z",
    "syncIdentifier" : "394818CF-99CD-4B12-99CD-0E678414986B"
  },
  "settings" : {
    "syncIdentifier" : "2B03D96C-99CD-4140-99CD-80C3E64D6011"
  },
  "syncIdentifier" : "2A67A303-5203-4CB8-8263-79498265368E",
  "warnings" : [
    {
      "id" : "one"
    },
    {
      "details" : {
        "size" : "small"
      },
      "id" : "two"
    }
  ]
}
"""
        )
    }

    private func assertStoredDosingDecisionCodable(_ original: StoredDosingDecision, encodesJSON string: String) throws {
        let data = try encoder.encode(original)
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
        let decoded = try decoder.decode(StoredDosingDecision.self, from: data)
        XCTAssertEqual(decoded, original)
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

extension StoredDosingDecision: Equatable {
    public static func == (lhs: StoredDosingDecision, rhs: StoredDosingDecision) -> Bool {
        return lhs.date == rhs.date &&
            lhs.controllerTimeZone == rhs.controllerTimeZone &&
            lhs.reason == rhs.reason &&
            lhs.settings == rhs.settings &&
            lhs.controllerStatus == rhs.controllerStatus &&
            lhs.pumpManagerStatus == rhs.pumpManagerStatus &&
            lhs.cgmManagerStatus == rhs.cgmManagerStatus &&
            lhs.lastReservoirValue == rhs.lastReservoirValue &&
            lhs.historicalGlucose == rhs.historicalGlucose &&
            lhs.originalCarbEntry == rhs.originalCarbEntry &&
            lhs.carbEntry == rhs.carbEntry &&
            lhs.manualGlucoseSample == rhs.manualGlucoseSample &&
            lhs.carbsOnBoard == rhs.carbsOnBoard &&
            lhs.insulinOnBoard == rhs.insulinOnBoard &&
            lhs.glucoseTargetRangeSchedule == rhs.glucoseTargetRangeSchedule &&
            lhs.predictedGlucose == rhs.predictedGlucose &&
            lhs.automaticDoseRecommendation == rhs.automaticDoseRecommendation &&
            lhs.manualBolusRecommendation == rhs.manualBolusRecommendation &&
            lhs.manualBolusRequested == rhs.manualBolusRequested &&
            lhs.warnings == rhs.warnings &&
            lhs.errors == rhs.errors &&
            lhs.syncIdentifier == rhs.syncIdentifier
    }
}

extension StoredDosingDecision.LastReservoirValue: Equatable {
    public static func == (lhs: StoredDosingDecision.LastReservoirValue, rhs: StoredDosingDecision.LastReservoirValue) -> Bool {
        return lhs.startDate == rhs.startDate && lhs.unitVolume == rhs.unitVolume
    }
}

extension ManualBolusRecommendationWithDate: Equatable {
    public static func == (lhs: ManualBolusRecommendationWithDate, rhs: ManualBolusRecommendationWithDate) -> Bool {
        return lhs.recommendation == rhs.recommendation && lhs.date == rhs.date
    }
}

extension ManualBolusRecommendation: Equatable {
    public static func == (lhs: ManualBolusRecommendation, rhs: ManualBolusRecommendation) -> Bool {
        return lhs.amount == rhs.amount && lhs.pendingInsulin == rhs.pendingInsulin && lhs.notice == rhs.notice
    }
}

fileprivate extension StoredDosingDecision {
    static var test: StoredDosingDecision {
        let controllerTimeZone = TimeZone(identifier: "America/Los_Angeles")!
        let scheduleTimeZone = TimeZone(secondsFromGMT: TimeZone(identifier: "America/Phoenix")!.secondsFromGMT())!
        let reason = "test"
        let settings = StoredDosingDecision.Settings(syncIdentifier: UUID(uuidString: "2B03D96C-99CD-4140-99CD-80C3E64D6011")!)
        let scheduleOverride = TemporaryScheduleOverride(context: .preMeal,
                                                         settings: TemporaryScheduleOverrideSettings(unit: .milligramsPerDeciliter,
                                                                                                     targetRange: DoubleRange(minValue: 80.0,
                                                                                                                              maxValue: 90.0),
                                                                                                     insulinNeedsScaleFactor: 1.5),
                                                         startDate: dateFormatter.date(from: "2020-05-14T22:22:01Z")!,
                                                         duration: .finite(.hours(1)),
                                                         enactTrigger: .local,
                                                         syncIdentifier: UUID(uuidString: "394818CF-99CD-4B12-99CD-0E678414986B")!)
        let controllerStatus = StoredDosingDecision.ControllerStatus(batteryState: .charging,
                                                                     batteryLevel: 0.5)
        let pumpManagerStatus = PumpManagerStatus(timeZone: scheduleTimeZone,
                                                  device: HKDevice(name: "Pump Name",
                                                                   manufacturer: "Pump Manufacturer",
                                                                   model: "Pump Model",
                                                                   hardwareVersion: "Pump Hardware Version",
                                                                   firmwareVersion: "Pump Firmware Version",
                                                                   softwareVersion: "Pump Software Version",
                                                                   localIdentifier: "Pump Local Identifier",
                                                                   udiDeviceIdentifier: "Pump UDI Device Identifier"),
                                                  pumpBatteryChargeRemaining: 0.75,
                                                  basalDeliveryState: .initiatingTempBasal,
                                                  bolusState: .noBolus,
                                                  insulinType: .novolog)
        let cgmManagerStatus = CGMManagerStatus(hasValidSensorSession: true,
                                                lastCommunicationDate: dateFormatter.date(from: "2020-05-14T22:07:01Z")!,
                                                device: HKDevice(name: "CGM Name",
                                                                 manufacturer: "CGM Manufacturer",
                                                                 model: "CGM Model",
                                                                 hardwareVersion: "CGM Hardware Version",
                                                                 firmwareVersion: "CGM Firmware Version",
                                                                 softwareVersion: "CGM Software Version",
                                                                 localIdentifier: "CGM Local Identifier",
                                                                 udiDeviceIdentifier: "CGM UDI Device Identifier"))
        let lastReservoirValue = StoredDosingDecision.LastReservoirValue(startDate: dateFormatter.date(from: "2020-05-14T22:07:19Z")!,
                                                                         unitVolume: 113.3)
        let historicalGlucose = [HistoricalGlucoseValue(startDate: dateFormatter.date(from: "2020-05-14T22:29:15Z")!,
                                                        quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 117.3)),
                                 HistoricalGlucoseValue(startDate: dateFormatter.date(from: "2020-05-14T22:33:15Z")!,
                                                        quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 119.5)),
                                 HistoricalGlucoseValue(startDate: dateFormatter.date(from: "2020-05-14T22:38:15Z")!,
                                                        quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 121.8))]
        let originalCarbEntry = StoredCarbEntry(uuid: UUID(uuidString: "18CF3948-0B3D-4B12-8BFE-14986B0E6784")!,
                                                provenanceIdentifier: "com.loopkit.loop",
                                                syncIdentifier: "2B03D96C-6F5D-4140-99CD-80C3E64D6010",
                                                syncVersion: 1,
                                                startDate: dateFormatter.date(from: "2020-01-02T03:00:23Z")!,
                                                quantity: HKQuantity(unit: .gram(), doubleValue: 19),
                                                foodType: "Pizza",
                                                absorptionTime: .hours(5),
                                                createdByCurrentApp: true,
                                                userCreatedDate: dateFormatter.date(from: "2020-05-14T22:06:12Z")!,
                                                userUpdatedDate: nil)
        let carbEntry = StoredCarbEntry(uuid: UUID(uuidString: "135CDABE-9343-7242-4233-1020384789AE")!,
                                        provenanceIdentifier: "com.loopkit.loop",
                                        syncIdentifier: "2B03D96C-6F5D-4140-99CD-80C3E64D6010",
                                        syncVersion: 2,
                                        startDate: dateFormatter.date(from: "2020-01-02T03:00:23Z")!,
                                        quantity: HKQuantity(unit: .gram(), doubleValue: 29),
                                        foodType: "Pizza",
                                        absorptionTime: .hours(5),
                                        createdByCurrentApp: true,
                                        userCreatedDate: dateFormatter.date(from: "2020-05-14T22:06:12Z")!,
                                        userUpdatedDate: dateFormatter.date(from: "2020-05-14T22:07:32Z")!)
        let manualGlucoseSample = StoredGlucoseSample(uuid: UUID(uuidString: "da0ced44-e4f1-49c4-baf8-6efa6d75525f")!,
                                                      provenanceIdentifier: "com.loopkit.loop",
                                                      syncIdentifier: "d3876f59-adb3-4a4f-8b29-315cda22062e",
                                                      syncVersion: 1,
                                                      startDate: dateFormatter.date(from: "2020-05-14T22:09:00Z")!,
                                                      quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 400),
                                                      condition: .aboveRange,
                                                      trend: .downDownDown,
                                                      trendRate: HKQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: -10.2),
                                                      isDisplayOnly: false,
                                                      wasUserEntered: true,
                                                      device: HKDevice(name: "Device Name",
                                                                       manufacturer: "Device Manufacturer",
                                                                       model: "Device Model",
                                                                       hardwareVersion: "Device Hardware Version",
                                                                       firmwareVersion: "Device Firmware Version",
                                                                       softwareVersion: "Device Software Version",
                                                                       localIdentifier: "Device Local Identifier",
                                                                       udiDeviceIdentifier: "Device UDI Device Identifier"),
                                                      healthKitEligibleDate: nil)
        let carbsOnBoard = CarbValue(startDate: dateFormatter.date(from: "2020-05-14T22:48:41Z")!,
                                     endDate: dateFormatter.date(from: "2020-05-14T23:18:41Z")!,
                                     quantity: HKQuantity(unit: .gram(), doubleValue: 45.5))
        let insulinOnBoard = InsulinValue(startDate: dateFormatter.date(from: "2020-05-14T22:38:26Z")!, value: 1.5)
        let glucoseTargetRangeSchedule = GlucoseRangeSchedule(rangeSchedule: DailyQuantitySchedule(unit: .milligramsPerDeciliter,
                                                                                                   dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: DoubleRange(minValue: 100.0, maxValue: 110.0)),
                                                                                                                RepeatingScheduleValue(startTime: .hours(7), value: DoubleRange(minValue: 90.0, maxValue: 100.0)),
                                                                                                                RepeatingScheduleValue(startTime: .hours(21), value: DoubleRange(minValue: 110.0, maxValue: 120.0))],
                                                                                                   timeZone: scheduleTimeZone)!,
                                                              override: GlucoseRangeSchedule.Override(value: DoubleRange(minValue: 105.0, maxValue: 115.0),
                                                                                                      start: dateFormatter.date(from: "2020-05-14T21:12:17Z")!,
                                                                                                      end: dateFormatter.date(from: "2020-05-14T23:12:17Z")!))
        let predictedGlucose = [PredictedGlucoseValue(startDate: dateFormatter.date(from: "2020-05-14T22:43:15Z")!,
                                                      quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 123.3)),
                                PredictedGlucoseValue(startDate: dateFormatter.date(from: "2020-05-14T22:48:15Z")!,
                                                      quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 125.5)),
                                PredictedGlucoseValue(startDate: dateFormatter.date(from: "2020-05-14T22:53:15Z")!,
                                                      quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 127.8))]
        let tempBasalRecommendation = TempBasalRecommendation(unitsPerHour: 0.75,
                                                              duration: .minutes(30))
        let automaticDoseRecommendation = AutomaticDoseRecommendation(basalAdjustment: tempBasalRecommendation, bolusUnits: 1.25)
        let manualBolusRecommendation = ManualBolusRecommendationWithDate(recommendation: ManualBolusRecommendation(amount: 1.2,
                                                                                                                    pendingInsulin: 0.75,
                                                                                                                    notice: .predictedGlucoseBelowTarget(minGlucose: PredictedGlucoseValue(startDate: dateFormatter.date(from: "2020-05-14T23:03:15Z")!,
                                                                                                                                                                                           quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 75.5)))),
                                                                          date: dateFormatter.date(from: "2020-05-14T22:38:16Z")!)
        let manualBolusRequested = 0.8
        let warnings: [Issue] = [Issue(id: "one"),
                                 Issue(id: "two", details: ["size": "small"])]
        let errors: [Issue] = [Issue(id: "alpha"),
                               Issue(id: "bravo", details: ["size": "tiny"])]

        return StoredDosingDecision(date: dateFormatter.date(from: "2020-05-14T22:38:14Z")!,
                                    controllerTimeZone: controllerTimeZone,
                                    reason: reason,
                                    settings: settings,
                                    scheduleOverride: scheduleOverride,
                                    controllerStatus: controllerStatus,
                                    pumpManagerStatus: pumpManagerStatus,
                                    cgmManagerStatus: cgmManagerStatus,
                                    lastReservoirValue: lastReservoirValue,
                                    historicalGlucose: historicalGlucose,
                                    originalCarbEntry: originalCarbEntry,
                                    carbEntry: carbEntry,
                                    manualGlucoseSample: manualGlucoseSample,
                                    carbsOnBoard: carbsOnBoard,
                                    insulinOnBoard: insulinOnBoard,
                                    glucoseTargetRangeSchedule: glucoseTargetRangeSchedule,
                                    predictedGlucose: predictedGlucose,
                                    automaticDoseRecommendation: automaticDoseRecommendation,
                                    manualBolusRecommendation: manualBolusRecommendation,
                                    manualBolusRequested: manualBolusRequested,
                                    warnings: warnings,
                                    errors: errors,
                                    syncIdentifier: UUID(uuidString: "2A67A303-5203-4CB8-8263-79498265368E")!)
    }

    private static let dateFormatter = ISO8601DateFormatter()
}
