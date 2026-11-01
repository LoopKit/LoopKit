//
//  CGMManagerTests.swift
//  LoopKitTests
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import XCTest

@testable import LoopKit

class CGMManagerTests: XCTestCase {
    @MainActor
    func testNotifyDelegateOfDeletionCallsCompletionOnDelegateQueue() async {
        let queueKey = DispatchSpecificKey<String>()
        let queue = DispatchQueue(label: "CGMManagerTests.delegateQueue")
        queue.setSpecific(key: queueKey, value: queue.label)

        let wantsDeletion = expectation(description: "cgmManagerWantsDeletion")
        let completed = expectation(description: "completion")
        let cgmManager = TestCGMManager()
        let delegate = TestCGMManagerDelegate(wantsDeletion: wantsDeletion)
        cgmManager.delegateQueue = queue
        cgmManager.cgmManagerDelegate = delegate

        cgmManager.notifyDelegateOfDeletion {
            XCTAssertEqual(DispatchQueue.getSpecific(key: queueKey), queue.label)
            completed.fulfill()
        }
        await fulfillment(of: [wantsDeletion, completed], timeout: 5, enforceOrder: true)
    }
}

private class TestCGMManager: CGMManager {
    static let pluginIdentifier = "TestCGMManager"
    var pluginIdentifier: String { Self.pluginIdentifier }
    let localizedTitle = "Test CGM"

    var cgmManagerDelegate: CGMManagerDelegate?
    var delegateQueue: DispatchQueue!
    let providesBLEHeartbeat = false
    let managedDataInterval: TimeInterval? = nil
    let shouldSyncToRemoteService = false
    let glucoseDisplay: GlucoseDisplayable? = nil
    let cgmManagerStatus = CGMManagerStatus(hasValidSensorSession: true, device: nil)
    let isOnboarded = true
    let inSignalLoss = false
    let isInoperable = false
    var debugDescription: String { "TestCGMManager" }

    init() {}

    required init?(rawState: RawStateValue) {}

    var rawState: RawStateValue { [:] }

    func fetchNewDataIfNeeded(_ completion: @escaping (CGMReadingResult) -> Void) {
        completion(.noData)
    }

    func acknowledgeAlert(alertIdentifier: Alert.AlertIdentifier) async throws {}

    func getSoundBaseURL() -> URL? { nil }

    func getSounds() -> [Alert.Sound] { [] }
}

private class TestCGMManagerDelegate: CGMManagerDelegate {
    private let wantsDeletion: XCTestExpectation

    init(wantsDeletion: XCTestExpectation) {
        self.wantsDeletion = wantsDeletion
    }

    func cgmManagerWantsDeletion(_ manager: CGMManager) async {
        wantsDeletion.fulfill()
    }

    func startDateToFilterNewData(for manager: CGMManager) -> Date? { nil }

    func cgmManager(_ manager: CGMManager, hasNew readingResult: CGMReadingResult) {}

    func cgmManager(_ manager: CGMManager, hasNew events: [PersistedCgmEvent]) {}

    func cgmManagerDidUpdateState(_ manager: CGMManager) {}

    func credentialStoragePrefix(for manager: CGMManager) -> String { "" }

    func cgmManager(_ manager: CGMManager, didUpdate status: CGMManagerStatus) {}

    func deviceManager(_ manager: DeviceManager, logEventForDeviceIdentifier deviceIdentifier: String?, type: DeviceLogEntryType, message: String, completion: ((Error?) -> Void)?) {}

    func issueAlert(_ alert: Alert) async {}

    func retractAlert(identifier: Alert.Identifier) async {}

    func doesIssuedAlertExist(identifier: Alert.Identifier) async throws -> Bool { false }

    func lookupAllUnretracted(managerIdentifier: String) async throws -> [PersistedAlert] { [] }

    func lookupAllUnacknowledgedUnretracted(managerIdentifier: String) async throws -> [PersistedAlert] { [] }

    func recordRetractedAlert(_ alert: Alert, at date: Date) async throws {}
}
