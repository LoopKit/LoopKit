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

    func testStoreDosingDecisionData() {
        let storeDosingDecisionDataHandler = expectation(description: "Store dosing decision data handler")
        let storeDosingDecisionDataCompletion = expectation(description: "Store dosing decision data completion")

        var handlerInvocation = 0

        dosingDecisionStoreHasUpdatedDosingDecisionDataHandler = { dosingDecisionStore in
            handlerInvocation += 1

            switch handlerInvocation {
            case 1:
                storeDosingDecisionDataHandler.fulfill()
            default:
                XCTFail("Unexpected handler invocation")
            }
        }

        dosingDecisionStore.storeDosingDecisionData(StoredDosingDecisionData()) {
            storeDosingDecisionDataCompletion.fulfill()
        }

        wait(for: [storeDosingDecisionDataHandler, storeDosingDecisionDataCompletion], timeout: 2, enforceOrder: true)
    }

    func testStoreDosingDecisionDataMultiple() {
        let storeDosingDecisionDataHandler1 = expectation(description: "Store dosing decision data handler 1")
        let storeDosingDecisionDataHandler2 = expectation(description: "Store dosing decision data handler 2")
        let storeDosingDecisionDataCompletion1 = expectation(description: "Store dosing decision data completion 1")
        let storeDosingDecisionDataCompletion2 = expectation(description: "Store dosing decision data completion 2")

        var handlerInvocation = 0

        dosingDecisionStoreHasUpdatedDosingDecisionDataHandler = { dosingDecisionStore in
            handlerInvocation += 1

            switch handlerInvocation {
            case 1:
                storeDosingDecisionDataHandler1.fulfill()
            case 2:
                storeDosingDecisionDataHandler2.fulfill()
            default:
                XCTFail("Unexpected handler invocation")
            }
        }

        dosingDecisionStore.storeDosingDecisionData(StoredDosingDecisionData()) {
            storeDosingDecisionDataCompletion1.fulfill()
        }

        dosingDecisionStore.storeDosingDecisionData(StoredDosingDecisionData()) {
            storeDosingDecisionDataCompletion2.fulfill()
        }

        wait(for: [storeDosingDecisionDataHandler1, storeDosingDecisionDataCompletion1, storeDosingDecisionDataHandler2, storeDosingDecisionDataCompletion2], timeout: 2, enforceOrder: true)
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
        dosingDecisionStore.executeDosingDecisionDataQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
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

        dosingDecisionStore.executeDosingDecisionDataQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
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

        dosingDecisionStore.executeDosingDecisionDataQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
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
        let dataStrings = [generateDataString(), generateDataString(), generateDataString()]

        addData(withDataStrings: dataStrings)

        dosingDecisionStore.executeDosingDecisionDataQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 3)
                XCTAssertEqual(data.count, 3)
                for (index, dataString) in dataStrings.enumerated() {
                    XCTAssertEqual(data[index].dataString, dataString)
                }
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testDataWithStaleQueryAnchor() {
        let dataStrings = [generateDataString(), generateDataString(), generateDataString()]

        addData(withDataStrings: dataStrings)

        queryAnchor.modificationCounter = 2

        dosingDecisionStore.executeDosingDecisionDataQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 3)
                XCTAssertEqual(data.count, 1)
                XCTAssertEqual(data[0].dataString, dataStrings[2])
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testDataWithCurrentQueryAnchor() {
        let dataStrings = [generateDataString(), generateDataString(), generateDataString()]

        addData(withDataStrings: dataStrings)

        queryAnchor.modificationCounter = 3

        dosingDecisionStore.executeDosingDecisionDataQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
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
        let dataStrings = [generateDataString(), generateDataString(), generateDataString()]

        addData(withDataStrings: dataStrings)

        limit = 0

        dosingDecisionStore.executeDosingDecisionDataQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
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
        let dataStrings = [generateDataString(), generateDataString(), generateDataString()]

        addData(withDataStrings: dataStrings)

        limit = 2

        dosingDecisionStore.executeDosingDecisionDataQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 2)
                XCTAssertEqual(data.count, 2)
                XCTAssertEqual(data[0].dataString, dataStrings[0])
                XCTAssertEqual(data[1].dataString, dataStrings[1])
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    private func addData(withDataStrings dataStrings: [String]) {
        let semaphore = DispatchSemaphore(value: 0)
        for dataString in dataStrings {
            self.dosingDecisionStore.storeDosingDecisionData(StoredDosingDecisionData(dataString: dataString)) { semaphore.signal() }
        }
        for _ in dataStrings { semaphore.wait() }
    }

    private func generateDataString() -> String {
        return UUID().uuidString
    }

}

extension StoredDosingDecisionData {
    init(date: Date = Date(), dataString: String = UUID().uuidString) {
        self.init(date: date, data: dataString.data(using: .utf8)!)
    }

    var dataString: String {
        return String(data: data, encoding: .utf8)!
    }
}
