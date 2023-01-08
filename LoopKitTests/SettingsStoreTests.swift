//
//  SettingsStoreTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 1/2/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
@testable import LoopKit

class SettingsStorePersistenceTests: PersistenceControllerTestCase, SettingsStoreDelegate {
    
    var settingsStore: SettingsStore!
    
    override func setUp() {
        super.setUp()
        
        settingsStoreHasUpdatedSettingsDataHandler = nil
        settingsStore = SettingsStore(store: cacheStore, expireAfter: .hours(1))
        settingsStore.delegate = self
    }
    
    override func tearDown() {
        settingsStore.delegate = nil
        settingsStore = nil
        settingsStoreHasUpdatedSettingsDataHandler = nil
        
        super.tearDown()
    }
    
    // MARK: - SettingsStoreDelegate
    
    var settingsStoreHasUpdatedSettingsDataHandler: ((_ : SettingsStore) -> Void)?
    
    func settingsStoreHasUpdatedSettingsData(_ settingsStore: SettingsStore) {
        settingsStoreHasUpdatedSettingsDataHandler?(settingsStore)
    }
    
    // MARK: -
    
    func testStoreSettings() {
        let storeSettingsHandler = expectation(description: "Store settings handler")
        let storeSettingsCompletion = expectation(description: "Store settings completion")
        
        var handlerInvocation = 0
        
        settingsStoreHasUpdatedSettingsDataHandler = { settingsStore in
            handlerInvocation += 1
            
            switch handlerInvocation {
            case 1:
                storeSettingsHandler.fulfill()
            default:
                XCTFail("Unexpected handler invocation")
            }
        }
        
        settingsStore.storeSettings(StoredSettings()) { _ in
            storeSettingsCompletion.fulfill()
        }
        
        wait(for: [storeSettingsHandler, storeSettingsCompletion], timeout: 2, enforceOrder: true)
    }
    
    func testStoreSettingsMultiple() {
        let storeSettingsHandler1 = expectation(description: "Store settings handler 1")
        let storeSettingsHandler2 = expectation(description: "Store settings handler 2")
        let storeSettingsCompletion1 = expectation(description: "Store settings completion 1")
        let storeSettingsCompletion2 = expectation(description: "Store settings completion 2")
        
        var handlerInvocation = 0
        
        settingsStoreHasUpdatedSettingsDataHandler = { settingsStore in
            handlerInvocation += 1
            
            switch handlerInvocation {
            case 1:
                storeSettingsHandler1.fulfill()
            case 2:
                storeSettingsHandler2.fulfill()
            default:
                XCTFail("Unexpected handler invocation")
            }
        }
        
        settingsStore.storeSettings(StoredSettings()) { _ in
            storeSettingsCompletion1.fulfill()
        }
        
        settingsStore.storeSettings(StoredSettings()) { _ in
            storeSettingsCompletion2.fulfill()
        }
        
        wait(for: [storeSettingsHandler1, storeSettingsCompletion1, storeSettingsHandler2, storeSettingsCompletion2], timeout: 2, enforceOrder: true)
    }
    
    // MARK: -

    func testSettingsObjectEncodable() throws {
        cacheStore.managedObjectContext.performAndWait {
            do {
                let object = SettingsObject(context: cacheStore.managedObjectContext)
                object.data = try PropertyListEncoder().encode(StoredSettings.test)
                object.date = dateFormatter.date(from: "2100-01-02T03:03:00Z")!
                object.modificationCounter = 123
                try assertSettingsObjectEncodable(object, encodesJSON: """
{
  "data" : {
    "automaticDosingStrategy" : 1,
    "basalRateSchedule" : {
      "items" : [
        {
          "startTime" : 0,
          "value" : 1
        },
        {
          "startTime" : 21600,
          "value" : 1.5
        },
        {
          "startTime" : 64800,
          "value" : 1.25
        }
      ],
      "referenceTimeInterval" : 0,
      "repeatInterval" : 86400,
      "timeZone" : {
        "identifier" : "GMT-0700"
      }
    },
    "bloodGlucoseUnit" : "mg/dL",
    "carbRatioSchedule" : {
      "unit" : "g",
      "valueSchedule" : {
        "items" : [
          {
            "startTime" : 0,
            "value" : 15
          },
          {
            "startTime" : 32400,
            "value" : 14
          },
          {
            "startTime" : 72000,
            "value" : 18
          }
        ],
        "referenceTimeInterval" : 0,
        "repeatInterval" : 86400,
        "timeZone" : {
          "identifier" : "GMT-0700"
        }
      }
    },
    "cgmDevice" : {
      "firmwareVersion" : "CGM Firmware Version",
      "hardwareVersion" : "CGM Hardware Version",
      "localIdentifier" : "CGM Local Identifier",
      "manufacturer" : "CGM Manufacturer",
      "model" : "CGM Model",
      "name" : "CGM Name",
      "softwareVersion" : "CGM Software Version",
      "udiDeviceIdentifier" : "CGM UDI Device Identifier"
    },
    "controllerDevice" : {
      "model" : "Controller Model",
      "modelIdentifier" : "Controller Model Identifier",
      "name" : "Controller Name",
      "systemName" : "Controller System Name",
      "systemVersion" : "Controller System Version"
    },
    "controllerTimeZone" : {
      "identifier" : "America/Los_Angeles"
    },
    "date" : "2020-05-14T22:48:15Z",
    "defaultRapidActingModel" : {
      "actionDuration" : 21600,
      "delay" : 600,
      "modelType" : "rapidAdult",
      "peakActivity" : 10800
    },
    "deviceToken" : "Device Token String",
    "dosingEnabled" : true,
    "glucoseTargetRangeSchedule" : {
      "override" : {
        "end" : "2020-05-14T14:48:15Z",
        "start" : "2020-05-14T12:48:15Z",
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
    "insulinSensitivitySchedule" : {
      "unit" : "mg/dL",
      "valueSchedule" : {
        "items" : [
          {
            "startTime" : 0,
            "value" : 45
          },
          {
            "startTime" : 10800,
            "value" : 40
          },
          {
            "startTime" : 54000,
            "value" : 50
          }
        ],
        "referenceTimeInterval" : 0,
        "repeatInterval" : 86400,
        "timeZone" : {
          "identifier" : "GMT-0700"
        }
      }
    },
    "insulinType" : 1,
    "maximumBasalRatePerHour" : 3.5,
    "maximumBolus" : 10,
    "notificationSettings" : {
      "alertSetting" : "disabled",
      "alertStyle" : "banner",
      "announcementSetting" : "enabled",
      "authorizationStatus" : "authorized",
      "badgeSetting" : "enabled",
      "carPlaySetting" : "notSupported",
      "criticalAlertSetting" : "enabled",
      "lockScreenSetting" : "disabled",
      "notificationCenterSetting" : "notSupported",
      "providesAppNotificationSettings" : true,
      "scheduledDeliverySetting" : "disabled",
      "showPreviewsSetting" : "whenAuthenticated",
      "soundSetting" : "enabled",
      "temporaryMuteAlertsSetting" : {
        "disabled" : {

        }
      },
      "timeSensitiveSetting" : "enabled"
    },
    "overridePresets" : [
      {
        "duration" : {
          "finite" : {
            "duration" : 3600
          }
        },
        "id" : "2A67A303-5203-4CB8-8263-79498265368E",
        "name" : "Apple",
        "settings" : {
          "insulinNeedsScaleFactor" : 2,
          "targetRangeInMgdl" : {
            "maxValue" : 140,
            "minValue" : 130
          }
        },
        "symbol" : "🍎"
      }
    ],
    "preMealOverride" : {
      "actualEnd" : {
        "type" : "natural"
      },
      "context" : "preMeal",
      "duration" : "indefinite",
      "enactTrigger" : "local",
      "settings" : {
        "insulinNeedsScaleFactor" : 0.5,
        "targetRangeInMgdl" : {
          "maxValue" : 90,
          "minValue" : 80
        }
      },
      "startDate" : "2020-05-14T14:38:39Z",
      "syncIdentifier" : "2A67A303-5203-1234-8263-79498265368E"
    },
    "preMealTargetRange" : {
      "maxValue" : 90,
      "minValue" : 80
    },
    "pumpDevice" : {
      "firmwareVersion" : "Pump Firmware Version",
      "hardwareVersion" : "Pump Hardware Version",
      "localIdentifier" : "Pump Local Identifier",
      "manufacturer" : "Pump Manufacturer",
      "model" : "Pump Model",
      "name" : "Pump Name",
      "softwareVersion" : "Pump Software Version",
      "udiDeviceIdentifier" : "Pump UDI Device Identifier"
    },
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
      "enactTrigger" : {
        "remote" : {
          "address" : "127.0.0.1"
        }
      },
      "settings" : {
        "insulinNeedsScaleFactor" : 1.5,
        "targetRangeInMgdl" : {
          "maxValue" : 120,
          "minValue" : 110
        }
      },
      "startDate" : "2020-05-14T14:48:19Z",
      "syncIdentifier" : "2A67A303-1234-4CB8-8263-79498265368E"
    },
    "suspendThreshold" : {
      "unit" : "mg/dL",
      "value" : 75
    },
    "syncIdentifier" : "2A67A303-1234-4CB8-1234-79498265368E",
    "workoutTargetRange" : {
      "maxValue" : 160,
      "minValue" : 150
    }
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

    private func assertSettingsObjectEncodable(_ original: SettingsObject, encodesJSON string: String) throws {
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

class SettingsStoreQueryAnchorTests: XCTestCase {
    
    var rawValue: SettingsStore.QueryAnchor.RawValue = [
        "modificationCounter": Int64(123)
    ]
    
    func testInitializerDefault() {
        let queryAnchor = SettingsStore.QueryAnchor()
        XCTAssertEqual(queryAnchor.modificationCounter, 0)
    }
    
    func testInitializerRawValue() {
        let queryAnchor = SettingsStore.QueryAnchor(rawValue: rawValue)
        XCTAssertNotNil(queryAnchor)
        XCTAssertEqual(queryAnchor?.modificationCounter, 123)
    }
    
    func testInitializerRawValueMissingModificationCounter() {
        rawValue["modificationCounter"] = nil
        XCTAssertNil(SettingsStore.QueryAnchor(rawValue: rawValue))
    }
    
    func testInitializerRawValueInvalidModificationCounter() {
        rawValue["modificationCounter"] = "123"
        XCTAssertNil(SettingsStore.QueryAnchor(rawValue: rawValue))
    }
    
    func testRawValueWithDefault() {
        let rawValue = SettingsStore.QueryAnchor().rawValue
        XCTAssertEqual(rawValue.count, 1)
        XCTAssertEqual(rawValue["modificationCounter"] as? Int64, Int64(0))
    }
    
    func testRawValueWithNonDefault() {
        var queryAnchor = SettingsStore.QueryAnchor()
        queryAnchor.modificationCounter = 123
        let rawValue = queryAnchor.rawValue
        XCTAssertEqual(rawValue.count, 1)
        XCTAssertEqual(rawValue["modificationCounter"] as? Int64, Int64(123))
    }
    
}

class SettingsStoreQueryTests: PersistenceControllerTestCase {
    
    var settingsStore: SettingsStore!
    var completion: XCTestExpectation!
    var queryAnchor: SettingsStore.QueryAnchor!
    var limit: Int!
    
    override func setUp() {
        super.setUp()
        
        settingsStore = SettingsStore(store: cacheStore, expireAfter: .hours(1))
        completion = expectation(description: "Completion")
        queryAnchor = SettingsStore.QueryAnchor()
        limit = Int.max
    }
    
    override func tearDown() {
        limit = nil
        queryAnchor = nil
        completion = nil
        settingsStore = nil
        
        super.tearDown()
    }
    
    // MARK: -
    
    func testEmptyWithDefaultQueryAnchor() {
        settingsStore.executeSettingsQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
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
        
        settingsStore.executeSettingsQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
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
        
        settingsStore.executeSettingsQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
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
        
        settingsStore.executeSettingsQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
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
        
        settingsStore.executeSettingsQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
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
        
        settingsStore.executeSettingsQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
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
        
        settingsStore.executeSettingsQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
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
        
        settingsStore.executeSettingsQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
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
            self.settingsStore.storeSettings(StoredSettings(syncIdentifier: syncIdentifier)) { _ in semaphore.signal() }
        }
        for _ in syncIdentifiers { semaphore.wait() }
    }
    
    private func generateSyncIdentifier() -> UUID { UUID() }
}

class SettingsStoreCriticalEventLogTests: PersistenceControllerTestCase {
    var settingsStore: SettingsStore!
    var outputStream: MockOutputStream!
    var progress: Progress!
    
    override func setUp() {
        super.setUp()

        let settings = [StoredSettings(date: dateFormatter.date(from: "2100-01-02T03:08:00Z")!, controllerTimeZone: TimeZone(identifier: "America/Los_Angeles")!, syncIdentifier: UUID(uuidString: "18CF3948-0B3D-4B12-8BFE-14986B0E6784")!),
                        StoredSettings(date: dateFormatter.date(from: "2100-01-02T03:10:00Z")!, controllerTimeZone: TimeZone(identifier: "America/Los_Angeles")!, syncIdentifier: UUID(uuidString: "C86DEB61-68E9-464E-9DD5-96A9CB445FD3")!),
                        StoredSettings(date: dateFormatter.date(from: "2100-01-02T03:04:00Z")!, controllerTimeZone: TimeZone(identifier: "America/Los_Angeles")!, syncIdentifier: UUID(uuidString: "2B03D96C-6F5D-4140-99CD-80C3E64D6010")!),
                        StoredSettings(date: dateFormatter.date(from: "2100-01-02T03:06:00Z")!, controllerTimeZone: TimeZone(identifier: "America/Los_Angeles")!, syncIdentifier: UUID(uuidString: "FF1C4F01-3558-4FB2-957E-FA1522C4735E")!),
                        StoredSettings(date: dateFormatter.date(from: "2100-01-02T03:02:00Z")!, controllerTimeZone: TimeZone(identifier: "America/Los_Angeles")!, syncIdentifier: UUID(uuidString: "71B699D7-0E8F-4B13-B7A1-E7751EB78E74")!)]

        settingsStore = SettingsStore(store: cacheStore, expireAfter: .hours(1))

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        settingsStore.addStoredSettings(settings: settings) { error in
            XCTAssertNil(error)
            dispatchGroup.leave()
        }
        dispatchGroup.wait()

        outputStream = MockOutputStream()
        progress = Progress()
    }

    override func tearDown() {
        settingsStore = nil

        super.tearDown()
    }
    
    func testExportProgressTotalUnitCount() {
        switch settingsStore.exportProgressTotalUnitCount(startDate: dateFormatter.date(from: "2100-01-02T03:03:00Z")!,
                                                          endDate: dateFormatter.date(from: "2100-01-02T03:09:00Z")!) {
        case .failure(let error):
            XCTFail("Unexpected failure: \(error)")
        case .success(let progressTotalUnitCount):
            XCTAssertEqual(progressTotalUnitCount, 3 * 11)
        }
    }
    
    func testExportProgressTotalUnitCountEmpty() {
        switch settingsStore.exportProgressTotalUnitCount(startDate: dateFormatter.date(from: "2100-01-02T03:00:00Z")!,
                                                          endDate: dateFormatter.date(from: "2100-01-02T03:01:00Z")!) {
        case .failure(let error):
            XCTFail("Unexpected failure: \(error)")
        case .success(let progressTotalUnitCount):
            XCTAssertEqual(progressTotalUnitCount, 0)
        }
    }

    func testExport() {
        XCTAssertNil(settingsStore.export(startDate: dateFormatter.date(from: "2100-01-02T03:03:00Z")!,
                                          endDate: dateFormatter.date(from: "2100-01-02T03:09:00Z")!,
                                          to: outputStream,
                                          progress: progress))
        XCTAssertEqual(outputStream.string, """
[
{"data":{"automaticDosingStrategy":0,"bloodGlucoseUnit":"mg/dL","controllerTimeZone":{"identifier":"America/Los_Angeles"},"date":"2100-01-02T03:08:00.000Z","dosingEnabled":false,"syncIdentifier":"18CF3948-0B3D-4B12-8BFE-14986B0E6784"},"date":"2100-01-02T03:08:00.000Z","modificationCounter":1},
{"data":{"automaticDosingStrategy":0,"bloodGlucoseUnit":"mg/dL","controllerTimeZone":{"identifier":"America/Los_Angeles"},"date":"2100-01-02T03:04:00.000Z","dosingEnabled":false,"syncIdentifier":"2B03D96C-6F5D-4140-99CD-80C3E64D6010"},"date":"2100-01-02T03:04:00.000Z","modificationCounter":3},
{"data":{"automaticDosingStrategy":0,"bloodGlucoseUnit":"mg/dL","controllerTimeZone":{"identifier":"America/Los_Angeles"},"date":"2100-01-02T03:06:00.000Z","dosingEnabled":false,"syncIdentifier":"FF1C4F01-3558-4FB2-957E-FA1522C4735E"},"date":"2100-01-02T03:06:00.000Z","modificationCounter":4}
]
"""
        )
        XCTAssertEqual(progress.completedUnitCount, 3 * 11)
    }

    func testExportEmpty() {
        XCTAssertNil(settingsStore.export(startDate: dateFormatter.date(from: "2100-01-02T03:00:00Z")!,
                                          endDate: dateFormatter.date(from: "2100-01-02T03:01:00Z")!,
                                          to: outputStream,
                                          progress: progress))
        XCTAssertEqual(outputStream.string, "[]")
        XCTAssertEqual(progress.completedUnitCount, 0)
    }

    func testExportCancelled() {
        progress.cancel()
        XCTAssertEqual(settingsStore.export(startDate: dateFormatter.date(from: "2100-01-02T03:03:00Z")!,
                                            endDate: dateFormatter.date(from: "2100-01-02T03:09:00Z")!,
                                            to: outputStream,
                                            progress: progress) as? CriticalEventLogError, CriticalEventLogError.cancelled)
    }

    private let dateFormatter = ISO8601DateFormatter()
}

class StoredSettingsCodableTests: XCTestCase {
    func testStoredSettingsCodable() throws {
        try assertStoredSettingsCodable(StoredSettings.test, encodesJSON: """
{
  "automaticDosingStrategy" : 1,
  "basalRateSchedule" : {
    "items" : [
      {
        "startTime" : 0,
        "value" : 1
      },
      {
        "startTime" : 21600,
        "value" : 1.5
      },
      {
        "startTime" : 64800,
        "value" : 1.25
      }
    ],
    "referenceTimeInterval" : 0,
    "repeatInterval" : 86400,
    "timeZone" : {
      "identifier" : "GMT-0700"
    }
  },
  "bloodGlucoseUnit" : "mg/dL",
  "carbRatioSchedule" : {
    "unit" : "g",
    "valueSchedule" : {
      "items" : [
        {
          "startTime" : 0,
          "value" : 15
        },
        {
          "startTime" : 32400,
          "value" : 14
        },
        {
          "startTime" : 72000,
          "value" : 18
        }
      ],
      "referenceTimeInterval" : 0,
      "repeatInterval" : 86400,
      "timeZone" : {
        "identifier" : "GMT-0700"
      }
    }
  },
  "cgmDevice" : {
    "firmwareVersion" : "CGM Firmware Version",
    "hardwareVersion" : "CGM Hardware Version",
    "localIdentifier" : "CGM Local Identifier",
    "manufacturer" : "CGM Manufacturer",
    "model" : "CGM Model",
    "name" : "CGM Name",
    "softwareVersion" : "CGM Software Version",
    "udiDeviceIdentifier" : "CGM UDI Device Identifier"
  },
  "controllerDevice" : {
    "model" : "Controller Model",
    "modelIdentifier" : "Controller Model Identifier",
    "name" : "Controller Name",
    "systemName" : "Controller System Name",
    "systemVersion" : "Controller System Version"
  },
  "controllerTimeZone" : {
    "identifier" : "America/Los_Angeles"
  },
  "date" : "2020-05-14T22:48:15Z",
  "defaultRapidActingModel" : {
    "actionDuration" : 21600,
    "delay" : 600,
    "modelType" : "rapidAdult",
    "peakActivity" : 10800
  },
  "deviceToken" : "Device Token String",
  "dosingEnabled" : true,
  "glucoseTargetRangeSchedule" : {
    "override" : {
      "end" : "2020-05-14T14:48:15Z",
      "start" : "2020-05-14T12:48:15Z",
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
  "insulinSensitivitySchedule" : {
    "unit" : "mg/dL",
    "valueSchedule" : {
      "items" : [
        {
          "startTime" : 0,
          "value" : 45
        },
        {
          "startTime" : 10800,
          "value" : 40
        },
        {
          "startTime" : 54000,
          "value" : 50
        }
      ],
      "referenceTimeInterval" : 0,
      "repeatInterval" : 86400,
      "timeZone" : {
        "identifier" : "GMT-0700"
      }
    }
  },
  "insulinType" : 1,
  "maximumBasalRatePerHour" : 3.5,
  "maximumBolus" : 10,
  "notificationSettings" : {
    "alertSetting" : "disabled",
    "alertStyle" : "banner",
    "announcementSetting" : "enabled",
    "authorizationStatus" : "authorized",
    "badgeSetting" : "enabled",
    "carPlaySetting" : "notSupported",
    "criticalAlertSetting" : "enabled",
    "lockScreenSetting" : "disabled",
    "notificationCenterSetting" : "notSupported",
    "providesAppNotificationSettings" : true,
    "scheduledDeliverySetting" : "disabled",
    "showPreviewsSetting" : "whenAuthenticated",
    "soundSetting" : "enabled",
    "temporaryMuteAlertsSetting" : {
      "disabled" : {

      }
    },
    "timeSensitiveSetting" : "enabled"
  },
  "overridePresets" : [
    {
      "duration" : {
        "finite" : {
          "duration" : 3600
        }
      },
      "id" : "2A67A303-5203-4CB8-8263-79498265368E",
      "name" : "Apple",
      "settings" : {
        "insulinNeedsScaleFactor" : 2,
        "targetRangeInMgdl" : {
          "maxValue" : 140,
          "minValue" : 130
        }
      },
      "symbol" : "🍎"
    }
  ],
  "preMealOverride" : {
    "actualEnd" : {
      "type" : "natural"
    },
    "context" : "preMeal",
    "duration" : "indefinite",
    "enactTrigger" : "local",
    "settings" : {
      "insulinNeedsScaleFactor" : 0.5,
      "targetRangeInMgdl" : {
        "maxValue" : 90,
        "minValue" : 80
      }
    },
    "startDate" : "2020-05-14T14:38:39Z",
    "syncIdentifier" : "2A67A303-5203-1234-8263-79498265368E"
  },
  "preMealTargetRange" : {
    "maxValue" : 90,
    "minValue" : 80
  },
  "pumpDevice" : {
    "firmwareVersion" : "Pump Firmware Version",
    "hardwareVersion" : "Pump Hardware Version",
    "localIdentifier" : "Pump Local Identifier",
    "manufacturer" : "Pump Manufacturer",
    "model" : "Pump Model",
    "name" : "Pump Name",
    "softwareVersion" : "Pump Software Version",
    "udiDeviceIdentifier" : "Pump UDI Device Identifier"
  },
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
    "enactTrigger" : {
      "remote" : {
        "address" : "127.0.0.1"
      }
    },
    "settings" : {
      "insulinNeedsScaleFactor" : 1.5,
      "targetRangeInMgdl" : {
        "maxValue" : 120,
        "minValue" : 110
      }
    },
    "startDate" : "2020-05-14T14:48:19Z",
    "syncIdentifier" : "2A67A303-1234-4CB8-8263-79498265368E"
  },
  "suspendThreshold" : {
    "unit" : "mg/dL",
    "value" : 75
  },
  "syncIdentifier" : "2A67A303-1234-4CB8-1234-79498265368E",
  "workoutTargetRange" : {
    "maxValue" : 160,
    "minValue" : 150
  }
}
"""
        )
    }
    
    private func assertStoredSettingsCodable(_ original: StoredSettings, encodesJSON string: String) throws {
        let data = try encoder.encode(original)
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
        let decoded = try decoder.decode(StoredSettings.self, from: data)
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

fileprivate extension StoredSettings {
    static var test: StoredSettings {
        let controllerTimeZone = TimeZone(identifier: "America/Los_Angeles")!
        let scheduleTimeZone = TimeZone(secondsFromGMT: TimeZone(identifier: "America/Phoenix")!.secondsFromGMT())!
        let dosingEnabled = true
        let glucoseTargetRangeSchedule = GlucoseRangeSchedule(rangeSchedule: DailyQuantitySchedule(unit: .milligramsPerDeciliter,
                                                                                                   dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: DoubleRange(minValue: 100.0, maxValue: 110.0)),
                                                                                                                RepeatingScheduleValue(startTime: .hours(7), value: DoubleRange(minValue: 90.0, maxValue: 100.0)),
                                                                                                                RepeatingScheduleValue(startTime: .hours(21), value: DoubleRange(minValue: 110.0, maxValue: 120.0))],
                                                                                                   timeZone: scheduleTimeZone)!,
                                                              override: GlucoseRangeSchedule.Override(value: DoubleRange(minValue: 105.0, maxValue: 115.0),
                                                                                                      start: dateFormatter.date(from: "2020-05-14T12:48:15Z")!,
                                                                                                      end: dateFormatter.date(from: "2020-05-14T14:48:15Z")!))
        let preMealTargetRange = DoubleRange(minValue: 80.0, maxValue: 90.0).quantityRange(for: .milligramsPerDeciliter)
        let workoutTargetRange = DoubleRange(minValue: 150.0, maxValue: 160.0).quantityRange(for: .milligramsPerDeciliter)
        let overridePresets = [TemporaryScheduleOverridePreset(id: UUID(uuidString: "2A67A303-5203-4CB8-8263-79498265368E")!,
                                                               symbol: "🍎",
                                                               name: "Apple",
                                                               settings: TemporaryScheduleOverrideSettings(unit: .milligramsPerDeciliter,
                                                                                                           targetRange: DoubleRange(minValue: 130.0, maxValue: 140.0),
                                                                                                           insulinNeedsScaleFactor: 2.0),
                                                               duration: .finite(.minutes(60)))]
        let scheduleOverride = TemporaryScheduleOverride(context: .preMeal,
                                                         settings: TemporaryScheduleOverrideSettings(unit: .milligramsPerDeciliter,
                                                                                                     targetRange: DoubleRange(minValue: 110.0, maxValue: 120.0),
                                                                                                     insulinNeedsScaleFactor: 1.5),
                                                         startDate: dateFormatter.date(from: "2020-05-14T14:48:19Z")!,
                                                         duration: .finite(.minutes(60)),
                                                         enactTrigger: .remote("127.0.0.1"),
                                                         syncIdentifier: UUID(uuidString: "2A67A303-1234-4CB8-8263-79498265368E")!)
        let preMealOverride = TemporaryScheduleOverride(context: .preMeal,
                                                        settings: TemporaryScheduleOverrideSettings(unit: .milligramsPerDeciliter,
                                                                                                    targetRange: DoubleRange(minValue: 80.0, maxValue: 90.0),
                                                                                                    insulinNeedsScaleFactor: 0.5),
                                                        startDate: dateFormatter.date(from: "2020-05-14T14:38:39Z")!,
                                                        duration: .indefinite,
                                                        enactTrigger: .local,
                                                        syncIdentifier: UUID(uuidString: "2A67A303-5203-1234-8263-79498265368E")!)
        let maximumBasalRatePerHour = 3.5
        let maximumBolus = 10.0
        let suspendThreshold = GlucoseThreshold(unit: .milligramsPerDeciliter, value: 75.0)
        let deviceToken = "Device Token String"
        let insulinType = InsulinType.humalog
        let defaultRapidActingModel = StoredInsulinModel(modelType: .rapidAdult, delay: .minutes(10), actionDuration: .hours(6), peakActivity: .hours(3))
        let basalRateSchedule = BasalRateSchedule(dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: 1.0),
                                                               RepeatingScheduleValue(startTime: .hours(6), value: 1.5),
                                                               RepeatingScheduleValue(startTime: .hours(18), value: 1.25)],
                                                  timeZone: scheduleTimeZone)
        let insulinSensitivitySchedule = InsulinSensitivitySchedule(unit: .milligramsPerDeciliter,
                                                                    dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: 45.0),
                                                                                 RepeatingScheduleValue(startTime: .hours(3), value: 40.0),
                                                                                 RepeatingScheduleValue(startTime: .hours(15), value: 50.0)],
                                                                    timeZone: scheduleTimeZone)
        let carbRatioSchedule = CarbRatioSchedule(unit: .gram(),
                                                  dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: 15.0),
                                                               RepeatingScheduleValue(startTime: .hours(9), value: 14.0),
                                                               RepeatingScheduleValue(startTime: .hours(20), value: 18.0)],
                                                  timeZone: scheduleTimeZone)
        let notificationSettings = NotificationSettings(authorizationStatus: .authorized,
                                                        soundSetting: .enabled,
                                                        badgeSetting: .enabled,
                                                        alertSetting: .disabled,
                                                        notificationCenterSetting: .notSupported,
                                                        lockScreenSetting: .disabled,
                                                        carPlaySetting: .notSupported,
                                                        alertStyle: .banner,
                                                        showPreviewsSetting: .whenAuthenticated,
                                                        criticalAlertSetting: .enabled,
                                                        providesAppNotificationSettings: true,
                                                        announcementSetting: .enabled,
                                                        timeSensitiveSetting: .enabled,
                                                        scheduledDeliverySetting: .disabled,
                                                        temporaryMuteAlertsSetting: .disabled)
        let controllerDevice = StoredSettings.ControllerDevice(name: "Controller Name",
                                                               systemName: "Controller System Name",
                                                               systemVersion: "Controller System Version",
                                                               model: "Controller Model",
                                                               modelIdentifier: "Controller Model Identifier")
        let cgmDevice = HKDevice(name: "CGM Name",
                                 manufacturer: "CGM Manufacturer",
                                 model: "CGM Model",
                                 hardwareVersion: "CGM Hardware Version",
                                 firmwareVersion: "CGM Firmware Version",
                                 softwareVersion: "CGM Software Version",
                                 localIdentifier: "CGM Local Identifier",
                                 udiDeviceIdentifier: "CGM UDI Device Identifier")
        let pumpDevice = HKDevice(name: "Pump Name",
                                  manufacturer: "Pump Manufacturer",
                                  model: "Pump Model",
                                  hardwareVersion: "Pump Hardware Version",
                                  firmwareVersion: "Pump Firmware Version",
                                  softwareVersion: "Pump Software Version",
                                  localIdentifier: "Pump Local Identifier",
                                  udiDeviceIdentifier: "Pump UDI Device Identifier")
        let bloodGlucoseUnit = HKUnit.milligramsPerDeciliter

        return StoredSettings(date: dateFormatter.date(from: "2020-05-14T22:48:15Z")!,
                              controllerTimeZone: controllerTimeZone,
                              dosingEnabled: dosingEnabled,
                              glucoseTargetRangeSchedule: glucoseTargetRangeSchedule,
                              preMealTargetRange: preMealTargetRange,
                              workoutTargetRange: workoutTargetRange,
                              overridePresets: overridePresets,
                              scheduleOverride: scheduleOverride,
                              preMealOverride: preMealOverride,
                              maximumBasalRatePerHour: maximumBasalRatePerHour,
                              maximumBolus: maximumBolus,
                              suspendThreshold: suspendThreshold,
                              deviceToken: deviceToken,
                              insulinType: insulinType,
                              defaultRapidActingModel: defaultRapidActingModel,
                              basalRateSchedule: basalRateSchedule,
                              insulinSensitivitySchedule: insulinSensitivitySchedule,
                              carbRatioSchedule: carbRatioSchedule,
                              notificationSettings: notificationSettings,
                              controllerDevice: controllerDevice,
                              cgmDevice: cgmDevice,
                              pumpDevice: pumpDevice,
                              bloodGlucoseUnit: bloodGlucoseUnit,
                              automaticDosingStrategy: .automaticBolus,
                              syncIdentifier: UUID(uuidString: "2A67A303-1234-4CB8-1234-79498265368E")!)
    }

    private static let dateFormatter = ISO8601DateFormatter()
}
