//
//  MockCGMManager.swift
//  LoopKit
//
//  Created by Michael Pangburn on 11/20/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import HealthKit


public struct MockCGMState: SensorDisplayable {
    public var isStateValid: Bool

    public var trendType: GlucoseTrend?

    public var isLocal: Bool {
        return true
    }
}

public final class MockCGMManager: CGMManager {
    public static let managerIdentifier = "MockCGMManager"
    public static let localizedTitle = "Simulator"

    public var mockSensorState: MockCGMState? = MockCGMState(isStateValid: true, trendType: nil)

    public var sensorState: SensorDisplayable? {
        return mockSensorState
    }

    public var device: HKDevice? {
        return MockCGMDataSource.device
    }

    public var cgmManagerDelegate: CGMManagerDelegate?

    public var dataSource = MockCGMDataSource(model: .noData)

    public init?(rawState: RawStateValue) {
        // nothing to do here
    }

    public var rawState: RawStateValue {
        return [:]
    }

    public var appURL: URL? {
        return nil
    }

    public var providesBLEHeartbeat: Bool {
        return false
    }

    public var managedDataInterval: TimeInterval? {
        // TODO: Is a short duration here preferable to remove values from HK?
        return nil
    }

    public var shouldSyncToRemoteService: Bool {
        return false
    }

    public func fetchNewDataIfNeeded(_ completion: @escaping (CGMResult) -> Void) {
        dataSource.fetchNewData(completion)
    }

    public func deleteCGMData() {
        cgmManagerDelegate?.dataStore(for: self).deleteGlucoseSamples(fromDevice: MockCGMDataSource.device)
    }
}

extension MockCGMManager {
    public var debugDescription: String {
        // TODO:
        return ""
    }
}
