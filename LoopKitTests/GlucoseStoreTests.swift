//
//  GlucoseStoreTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 12/30/19.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
import CoreData
@testable import LoopKit


class GlucoseStoreTests: PersistenceControllerTestCase {
    var healthStore: HKHealthStoreMock!
    var glucoseStore: GlucoseStore!

    override func setUp() {
        super.setUp()
        
        healthStore = HKHealthStoreMock()
        glucoseStore = GlucoseStore(healthStore: healthStore,
                                    cacheStore: cacheStore,
                                    provenanceIdentifier: Bundle.main.bundleIdentifier!)
        let semaphore = DispatchSemaphore(value: 0)
        cacheStore.onReady { (error) in
            semaphore.signal()
        }
        semaphore.wait()
    }
    
    override func tearDown() {
        glucoseStore = nil
        healthStore = nil

        super.tearDown()
    }
    
    func testLatestGlucoseIsSetAfterStoreAndClearedAfterPurge() {
        let storeCompletion = expectation(description: "Storage completion")
        let storedQuantity = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 80)
        let device = HKDevice(name: "Unit Test Mock CGM",
            manufacturer: "Device Manufacturer",
            model: "Device Model",
            hardwareVersion: "Device Hardware Version",
            firmwareVersion: "Device Firmware Version",
            softwareVersion: "Device Software Version",
            localIdentifier: "Device Local Identifier",
            udiDeviceIdentifier: "Device UDI Device Identifier")
        let sample = NewGlucoseSample(date: Date(), quantity: storedQuantity, condition: nil, trend: nil, trendRate: nil, isDisplayOnly: false, wasUserEntered: false, syncIdentifier: "random", device: device)
        glucoseStore.addGlucoseSamples([sample]) { (result) in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(storedQuantity, samples.first!.quantity)
            }
            storeCompletion.fulfill()
        }
        wait(for: [storeCompletion], timeout: 2)
        XCTAssertEqual(storedQuantity, self.glucoseStore.latestGlucose?.quantity)

        let purgeCompletion = expectation(description: "Storage completion")
        
        let predicate = HKQuery.predicateForObjects(from: [device])
        glucoseStore.purgeAllGlucoseSamples(healthKitPredicate: predicate) { (error) in
            if let error = error {
                XCTFail("Unexpected failure: \(error)")
            }
            purgeCompletion.fulfill()
        }
        wait(for: [purgeCompletion], timeout: 2)
        XCTAssertNil(self.glucoseStore.latestGlucose)
    }
}

class GlucoseStoreRemoteDataServiceQueryAnchorTests: XCTestCase {
    var rawValue: GlucoseStore.QueryAnchor.RawValue = [
        "modificationCounter": Int64(123)
    ]
    
    func testInitializerDefault() {
        let queryAnchor = GlucoseStore.QueryAnchor()
        XCTAssertEqual(queryAnchor.modificationCounter, 0)
    }
    
    func testInitializerRawValue() {
        let queryAnchor = GlucoseStore.QueryAnchor(rawValue: rawValue)
        XCTAssertNotNil(queryAnchor)
        XCTAssertEqual(queryAnchor?.modificationCounter, 123)
    }
    
    func testInitializerRawValueMissingModificationCounter() {
        rawValue["modificationCounter"] = nil
        XCTAssertNil(GlucoseStore.QueryAnchor(rawValue: rawValue))
    }
    
    func testInitializerRawValueInvalidModificationCounter() {
        rawValue["modificationCounter"] = "123"
        XCTAssertNil(GlucoseStore.QueryAnchor(rawValue: rawValue))
    }
    
    func testRawValueWithDefault() {
        let rawValue = GlucoseStore.QueryAnchor().rawValue
        XCTAssertEqual(rawValue.count, 1)
        XCTAssertEqual(rawValue["modificationCounter"] as? Int64, Int64(0))
    }
    
    func testRawValueWithNonDefault() {
        var queryAnchor = GlucoseStore.QueryAnchor()
        queryAnchor.modificationCounter = 123
        let rawValue = queryAnchor.rawValue
        XCTAssertEqual(rawValue.count, 1)
        XCTAssertEqual(rawValue["modificationCounter"] as? Int64, Int64(123))
    }
}

class GlucoseStoreRemoteDataServiceQueryTests: PersistenceControllerTestCase {
    var healthStore: HKHealthStoreMock!
    var glucoseStore: GlucoseStore!
    var completion: XCTestExpectation!
    var queryAnchor: GlucoseStore.QueryAnchor!
    var limit: Int!

    override func setUp() {
        super.setUp()
        
        healthStore = HKHealthStoreMock()
        glucoseStore = GlucoseStore(healthStore: healthStore,
                                    cacheStore: cacheStore,
                                    provenanceIdentifier: Bundle.main.bundleIdentifier!)
        let semaphore = DispatchSemaphore(value: 0)
        cacheStore.onReady { (error) in
            semaphore.signal()
        }
        semaphore.wait()
        completion = expectation(description: "Completion")
        queryAnchor = GlucoseStore.QueryAnchor()
        limit = Int.max
    }
    
    override func tearDown() {
        limit = nil
        queryAnchor = nil
        completion = nil
        glucoseStore = nil
        healthStore = nil

        super.tearDown()
    }

    func testEmptyWithDefaultQueryAnchor() {
        glucoseStore.executeGlucoseQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
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

        glucoseStore.executeGlucoseQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
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

        glucoseStore.executeGlucoseQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
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
        
        glucoseStore.executeGlucoseQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 3)
                XCTAssertEqual(data.count, 3)
                for (index, syncIdentifier) in syncIdentifiers.enumerated() {
                    XCTAssertEqual(data[index].syncIdentifier, syncIdentifier)
                    XCTAssertEqual(data[index].syncVersion, index)
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
        
        glucoseStore.executeGlucoseQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 3)
                XCTAssertEqual(data.count, 1)
                XCTAssertEqual(data[0].syncIdentifier, syncIdentifiers[2])
                XCTAssertEqual(data[0].syncVersion, 2)
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testDataWithCurrentQueryAnchor() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        
        addData(withSyncIdentifiers: syncIdentifiers)
        
        queryAnchor.modificationCounter = 3
        
        glucoseStore.executeGlucoseQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
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

        glucoseStore.executeGlucoseQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
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
        
        glucoseStore.executeGlucoseQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 2)
                XCTAssertEqual(data.count, 2)
                XCTAssertEqual(data[0].syncIdentifier, syncIdentifiers[0])
                XCTAssertEqual(data[0].syncVersion, 0)
                XCTAssertEqual(data[1].syncIdentifier, syncIdentifiers[1])
                XCTAssertEqual(data[1].syncVersion, 1)
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    private func addData(withSyncIdentifiers syncIdentifiers: [String]) {
        cacheStore.managedObjectContext.performAndWait {
            for (index, syncIdentifier) in syncIdentifiers.enumerated() {
                let cachedGlucoseObject = CachedGlucoseObject(context: self.cacheStore.managedObjectContext)
                cachedGlucoseObject.uuid = UUID()
                cachedGlucoseObject.provenanceIdentifier = syncIdentifier
                cachedGlucoseObject.syncIdentifier = syncIdentifier
                cachedGlucoseObject.syncVersion = index
                cachedGlucoseObject.value = 123
                cachedGlucoseObject.unitString = HKUnit.milligramsPerDeciliter.unitString
                cachedGlucoseObject.startDate = Date()
                self.cacheStore.save()
            }
        }
    }

    private func generateSyncIdentifier() -> String {
        return UUID().uuidString
    }
}

class GlucoseStoreCriticalEventLogExportTests: PersistenceControllerTestCase {
    var glucoseStore: GlucoseStore!
    var outputStream: MockOutputStream!
    var progress: Progress!
    
    override func setUp() {
        super.setUp()

        let samples = [NewGlucoseSample(date: dateFormatter.date(from: "2100-01-02T03:08:00Z")!, quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 111), condition: nil, trend: nil, trendRate: nil, isDisplayOnly: false, wasUserEntered: false, syncIdentifier: "18CF3948-0B3D-4B12-8BFE-14986B0E6784", syncVersion: 1),
                       NewGlucoseSample(date: dateFormatter.date(from: "2100-01-02T03:10:00Z")!, quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 112), condition: nil, trend: .up, trendRate: HKQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: 1.0), isDisplayOnly: false, wasUserEntered: false, syncIdentifier: "C86DEB61-68E9-464E-9DD5-96A9CB445FD3", syncVersion: 2),
                       NewGlucoseSample(date: dateFormatter.date(from: "2100-01-02T03:04:00Z")!, quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 113), condition: nil, trend: .up, trendRate: HKQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: 1.0), isDisplayOnly: false, wasUserEntered: false, syncIdentifier: "2B03D96C-6F5D-4140-99CD-80C3E64D6010", syncVersion: 3),
                       NewGlucoseSample(date: dateFormatter.date(from: "2100-01-02T03:06:00Z")!, quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 114), condition: nil, trend: .up, trendRate: HKQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: 1.0), isDisplayOnly: false, wasUserEntered: false, syncIdentifier: "FF1C4F01-3558-4FB2-957E-FA1522C4735E", syncVersion: 4),
                       NewGlucoseSample(date: dateFormatter.date(from: "2100-01-02T03:02:00Z")!, quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 400), condition: .aboveRange, trend: .upUpUp, trendRate: HKQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: 1.0), isDisplayOnly: false, wasUserEntered: false, syncIdentifier: "71B699D7-0E8F-4B13-B7A1-E7751EB78E74", syncVersion: 5)]

        glucoseStore = GlucoseStore(healthStore: HKHealthStoreMock(),
                                    cacheStore: cacheStore,
                                    provenanceIdentifier: Bundle.main.bundleIdentifier!)

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        glucoseStore.addNewGlucoseSamples(samples: samples) { error in
            XCTAssertNil(error)
            dispatchGroup.leave()
        }
        dispatchGroup.wait()

        outputStream = MockOutputStream()
        progress = Progress()
    }

    override func tearDown() {
        glucoseStore = nil

        super.tearDown()
    }
    
    func testExportProgressTotalUnitCount() {
        switch glucoseStore.exportProgressTotalUnitCount(startDate: dateFormatter.date(from: "2100-01-02T03:03:00Z")!,
                                                         endDate: dateFormatter.date(from: "2100-01-02T03:09:00Z")!) {
        case .failure(let error):
            XCTFail("Unexpected failure: \(error)")
        case .success(let progressTotalUnitCount):
            XCTAssertEqual(progressTotalUnitCount, 3 * 1)
        }
    }
    
    func testExportProgressTotalUnitCountEmpty() {
        switch glucoseStore.exportProgressTotalUnitCount(startDate: dateFormatter.date(from: "2100-01-02T03:00:00Z")!,
                                                         endDate: dateFormatter.date(from: "2100-01-02T03:01:00Z")!) {
        case .failure(let error):
            XCTFail("Unexpected failure: \(error)")
        case .success(let progressTotalUnitCount):
            XCTAssertEqual(progressTotalUnitCount, 0)
        }
    }

    func testExport() {
        XCTAssertNil(glucoseStore.export(startDate: dateFormatter.date(from: "2100-01-02T03:03:00Z")!,
                                         endDate: dateFormatter.date(from: "2100-01-02T03:09:00Z")!,
                                         to: outputStream,
                                         progress: progress))
        XCTAssertEqual(outputStream.string, """
            [
            {"isDisplayOnly":false,"modificationCounter":1,"provenanceIdentifier":"com.apple.dt.xctest.tool","startDate":"2100-01-02T03:08:00.000Z","syncIdentifier":"18CF3948-0B3D-4B12-8BFE-14986B0E6784","syncVersion":1,"unitString":"mg/dL","value":111,"wasUserEntered":false},
            {"isDisplayOnly":false,"modificationCounter":3,"provenanceIdentifier":"com.apple.dt.xctest.tool","startDate":"2100-01-02T03:04:00.000Z","syncIdentifier":"2B03D96C-6F5D-4140-99CD-80C3E64D6010","syncVersion":3,"trend":3,"trendRateUnit":"mg/min·dL","trendRateValue":1,"unitString":"mg/dL","value":113,"wasUserEntered":false},
            {"isDisplayOnly":false,"modificationCounter":4,"provenanceIdentifier":"com.apple.dt.xctest.tool","startDate":"2100-01-02T03:06:00.000Z","syncIdentifier":"FF1C4F01-3558-4FB2-957E-FA1522C4735E","syncVersion":4,"trend":3,"trendRateUnit":"mg/min·dL","trendRateValue":1,"unitString":"mg/dL","value":114,"wasUserEntered":false}
            ]
            """
        )
        XCTAssertEqual(progress.completedUnitCount, 3 * 1)
    }

    func testExportEmpty() {
        XCTAssertNil(glucoseStore.export(startDate: dateFormatter.date(from: "2100-01-02T03:00:00Z")!,
                                         endDate: dateFormatter.date(from: "2100-01-02T03:01:00Z")!,
                                         to: outputStream,
                                         progress: progress))
        XCTAssertEqual(outputStream.string, "[]")
        XCTAssertEqual(progress.completedUnitCount, 0)
    }

    func testExportCancelled() {
        progress.cancel()
        XCTAssertEqual(glucoseStore.export(startDate: dateFormatter.date(from: "2100-01-02T03:03:00Z")!,
                                           endDate: dateFormatter.date(from: "2100-01-02T03:09:00Z")!,
                                           to: outputStream,
                                           progress: progress) as? CriticalEventLogError, CriticalEventLogError.cancelled)
    }

    private let dateFormatter = ISO8601DateFormatter()
}
