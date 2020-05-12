//
//  DosingDecisionStoreTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 1/6/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit

class DosingDecisionStorePersistenceTests: PersistenceControllerTestCase, DosingDecisionStoreDelegate {

    var dosingDecisionStore: DosingDecisionStore!

    override func setUp() {
        super.setUp()

        dosingDecisionStoreHasUpdatedDosingDecisionDataHandler = nil
        dosingDecisionStore = DosingDecisionStore(store: cacheStore, expireAfter: .hours(24))
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

        dosingDecisionStore.storeDosingDecision(StoredDosingDecision()) {
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

        dosingDecisionStore.storeDosingDecision(StoredDosingDecision()) {
            storeDosingDecisionCompletion1.fulfill()
        }

        dosingDecisionStore.storeDosingDecision(StoredDosingDecision()) {
            storeDosingDecisionCompletion2.fulfill()
        }

        wait(for: [storeDosingDecisionHandler1, storeDosingDecisionCompletion1, storeDosingDecisionHandler2, storeDosingDecisionCompletion2], timeout: 2, enforceOrder: true)
    }

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

        dosingDecisionStore = DosingDecisionStore(store: cacheStore, expireAfter: .hours(24))
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

    private func addData(withSyncIdentifiers syncIdentifiers: [String]) {
        let semaphore = DispatchSemaphore(value: 0)
        for (_, syncIdentifier) in syncIdentifiers.enumerated() {
            self.dosingDecisionStore.storeDosingDecision(StoredDosingDecision(syncIdentifier: syncIdentifier)) { semaphore.signal() }
        }
        for _ in syncIdentifiers { semaphore.wait() }
    }

    private func generateSyncIdentifier() -> String {
        return UUID().uuidString
    }

}
