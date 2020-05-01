//
//  SettingsStoreTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 1/2/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit

class SettingsStorePersistenceTests: XCTestCase, SettingsStoreCacheStore, SettingsStoreDelegate {

    var settingsStore: SettingsStore!

    override func setUp() {
        super.setUp()

        settingsStoreHasUpdatedSettingsDataHandler = nil
        settingsStoreModificationCounter = nil
        settingsStore = SettingsStore(storeCache: self)
        settingsStore.delegate = self
    }

    override func tearDown() {
        settingsStore.delegate = nil
        settingsStore = nil
        settingsStoreModificationCounter = nil
        settingsStoreHasUpdatedSettingsDataHandler = nil

        super.tearDown()
    }

    // MARK: - SettingsStoreCacheStore

    var settingsStoreModificationCounter: Int64?

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

        settingsStore.storeSettings(StoredSettings()) {
            XCTAssertEqual(self.settingsStoreModificationCounter, 1)
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

        settingsStore.storeSettings(StoredSettings()) {
            XCTAssertEqual(self.settingsStoreModificationCounter, 1)
            storeSettingsCompletion1.fulfill()
        }

        settingsStore.storeSettings(StoredSettings()) {
            XCTAssertEqual(self.settingsStoreModificationCounter, 2)
            storeSettingsCompletion2.fulfill()
        }

        wait(for: [storeSettingsHandler1, storeSettingsCompletion1, storeSettingsHandler2, storeSettingsCompletion2], timeout: 2, enforceOrder: true)
    }

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

class SettingsStoreQueryTests: XCTestCase, SettingsStoreCacheStore {

    var settingsStore: SettingsStore!
    var completion: XCTestExpectation!
    var queryAnchor: SettingsStore.QueryAnchor!
    var limit: Int!

    override func setUp() {
        super.setUp()

        settingsStoreModificationCounter = nil
        settingsStore = SettingsStore(storeCache: self)
        completion = expectation(description: "Completion")
        queryAnchor = SettingsStore.QueryAnchor()
        limit = Int.max
    }

    override func tearDown() {
        limit = nil
        queryAnchor = nil
        completion = nil
        settingsStore = nil
        settingsStoreModificationCounter = nil

        super.tearDown()
    }

    // MARK: - SettingsStoreCacheStore

    var settingsStoreModificationCounter: Int64?

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

    private func addData(withSyncIdentifiers syncIdentifiers: [String]) {
        for (_, syncIdentifier) in syncIdentifiers.enumerated() {
            self.settingsStore.storeSettings(StoredSettings(syncIdentifier: syncIdentifier)) {}
        }
    }

    private func generateSyncIdentifier() -> String {
        return UUID().uuidString
    }

}
