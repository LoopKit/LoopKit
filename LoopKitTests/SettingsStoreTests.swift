//
//  SettingsStoreTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 1/2/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit

class SettingsStorePersistenceTests: PersistenceControllerTestCase, SettingsStoreDelegate {

    var settingsStore: SettingsStore!

    override func setUp() {
        super.setUp()

        settingsStoreHasUpdatedSettingsDataHandler = nil
        settingsStore = SettingsStore(store: cacheStore, expireAfter: .hours(24))
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

        settingsStore.storeSettings(StoredSettings()) {
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
            storeSettingsCompletion1.fulfill()
        }

        settingsStore.storeSettings(StoredSettings()) {
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

class SettingsStoreQueryTests: PersistenceControllerTestCase {

    var settingsStore: SettingsStore!
    var completion: XCTestExpectation!
    var queryAnchor: SettingsStore.QueryAnchor!
    var limit: Int!

    override func setUp() {
        super.setUp()

        settingsStore = SettingsStore(store: cacheStore, expireAfter: .hours(24))
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

    private func addData(withSyncIdentifiers syncIdentifiers: [String]) {
        let semaphore = DispatchSemaphore(value: 0)
        for (_, syncIdentifier) in syncIdentifiers.enumerated() {
            self.settingsStore.storeSettings(StoredSettings(syncIdentifier: syncIdentifier)) { semaphore.signal() }
        }
        for _ in syncIdentifiers { semaphore.wait() }
    }

    private func generateSyncIdentifier() -> String {
        return UUID().uuidString
    }

}

class StoredSettingsCodableTests: XCTestCase {
    func testCodable() throws {
        let settings = StoredSettings(date: Date(),
                                      dosingEnabled: true,
                                      glucoseTargetRangeSchedule: GlucoseRangeSchedule(rangeSchedule: DailyQuantitySchedule(unit: .milligramsPerDeciliter,
                                                                                                                            dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: DoubleRange(minValue: 100.0, maxValue: 110.0)),
                                                                                                                                         RepeatingScheduleValue(startTime: .hours(7), value: DoubleRange(minValue: 90.0, maxValue: 100.0)),
                                                                                                                                         RepeatingScheduleValue(startTime: .hours(21), value: DoubleRange(minValue: 110.0, maxValue: 120.0))],
                                                                                                                            timeZone: TimeZone.currentFixed)!,
                                                                                       override: GlucoseRangeSchedule.Override(value: DoubleRange(minValue: 105.0, maxValue: 115.0),
                                                                                                                               start: Date(),
                                                                                                                               end: Date().addingTimeInterval(.minutes(30)))),
                                      preMealTargetRange: DoubleRange(minValue: 80.0, maxValue: 90.0),
                                      workoutTargetRange: DoubleRange(minValue: 150.0, maxValue: 160.0),
                                      overridePresets: [TemporaryScheduleOverridePreset(id: UUID(),
                                                                                        symbol: "🍎",
                                                                                        name: "Apple",
                                                                                        settings: TemporaryScheduleOverrideSettings(unit: .milligramsPerDeciliter,
                                                                                                                                    targetRange: DoubleRange(minValue: 130.0, maxValue: 140.0),
                                                                                                                                    insulinNeedsScaleFactor: 2.0),
                                                                                        duration: .finite(.minutes(60)))],
                                      scheduleOverride: TemporaryScheduleOverride(context: .preMeal,
                                                                                  settings: TemporaryScheduleOverrideSettings(unit: .milligramsPerDeciliter,
                                                                                                                              targetRange: DoubleRange(minValue: 110.0, maxValue: 120.0),
                                                                                                                              insulinNeedsScaleFactor: 1.5),
                                                                                  startDate: Date(),
                                                                                  duration: .finite(.minutes(60)),
                                                                                  enactTrigger: .remote("127.0.0.1"),
                                                                                  syncIdentifier: UUID()),
                                      preMealOverride: TemporaryScheduleOverride(context: .preMeal,
                                                                                 settings: TemporaryScheduleOverrideSettings(unit: .milligramsPerDeciliter,
                                                                                                                             targetRange: DoubleRange(minValue: 80.0, maxValue: 90.0),
                                                                                                                             insulinNeedsScaleFactor: 0.5),
                                                                                 startDate: Date(),
                                                                                 duration: .indefinite,
                                                                                 enactTrigger: .local,
                                                                                 syncIdentifier: UUID()),
                                      maximumBasalRatePerHour: 3.5,
                                      maximumBolus: 10.0,
                                      suspendThreshold: GlucoseThreshold(unit: .milligramsPerDeciliter, value: 75.0),
                                      deviceToken: "DeviceTokenString",
                                      insulinModel: StoredSettings.InsulinModel(modelType: .rapidAdult, actionDuration: .hours(6), peakActivity: .hours(3)),
                                      basalRateSchedule: BasalRateSchedule(dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: 1.0),
                                                                                        RepeatingScheduleValue(startTime: .hours(6), value: 1.5),
                                                                                        RepeatingScheduleValue(startTime: .hours(18), value: 1.25)],
                                                                           timeZone: TimeZone.currentFixed),
                                      insulinSensitivitySchedule: InsulinSensitivitySchedule(unit: .milligramsPerDeciliter,
                                                                                             dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: 45.0),
                                                                                                          RepeatingScheduleValue(startTime: .hours(3), value: 40.0),
                                                                                                          RepeatingScheduleValue(startTime: .hours(15), value: 50.0)],
                                                                                             timeZone: TimeZone.currentFixed),
                                      carbRatioSchedule: CarbRatioSchedule(unit: .gram(),
                                                                           dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: 15.0),
                                                                                        RepeatingScheduleValue(startTime: .hours(9), value: 14.0),
                                                                                        RepeatingScheduleValue(startTime: .hours(20), value: 18.0)],
                                                                           timeZone: TimeZone.currentFixed),
                                      bloodGlucoseUnit: .milligramsPerDeciliter,
                                      syncIdentifier: UUID().uuidString)
        try assertStoredSettingsCodable(settings)
    }

    func assertStoredSettingsCodable(_ original: StoredSettings) throws {
        let data = try PropertyListEncoder().encode(original)
        let decoded = try PropertyListDecoder().decode(StoredSettings.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}

extension StoredSettings: Equatable {
    public static func == (lhs: StoredSettings, rhs: StoredSettings) -> Bool {
        return lhs.date == rhs.date &&
            lhs.dosingEnabled == rhs.dosingEnabled &&
            lhs.glucoseTargetRangeSchedule == rhs.glucoseTargetRangeSchedule &&
            lhs.preMealTargetRange == rhs.preMealTargetRange &&
            lhs.workoutTargetRange == rhs.workoutTargetRange &&
            lhs.overridePresets == rhs.overridePresets &&
            lhs.scheduleOverride == rhs.scheduleOverride &&
            lhs.preMealOverride == rhs.preMealOverride &&
            lhs.maximumBasalRatePerHour == rhs.maximumBasalRatePerHour &&
            lhs.maximumBolus == rhs.maximumBolus &&
            lhs.suspendThreshold == rhs.suspendThreshold &&
            lhs.deviceToken == rhs.deviceToken &&
            lhs.insulinModel == rhs.insulinModel &&
            lhs.basalRateSchedule == rhs.basalRateSchedule &&
            lhs.insulinSensitivitySchedule == rhs.insulinSensitivitySchedule &&
            lhs.carbRatioSchedule == rhs.carbRatioSchedule &&
            lhs.bloodGlucoseUnit == rhs.bloodGlucoseUnit &&
            lhs.syncIdentifier == rhs.syncIdentifier
    }
}
