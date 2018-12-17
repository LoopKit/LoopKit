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

    public var mockSensorState: MockCGMState {
        didSet {
            cgmManagerDelegate?.cgmManagerDidUpdateState(self)
        }
    }

    public var sensorState: SensorDisplayable? {
        return mockSensorState
    }

    public var device: HKDevice? {
        return MockCGMDataSource.device
    }

    public var cgmManagerDelegate: CGMManagerDelegate?

    public var dataSource: MockCGMDataSource {
        didSet {
            cgmManagerDelegate?.cgmManagerDidUpdateState(self)
        }
    }

    private var glucoseUpdateTimer: Timer?

    public init?(rawState: RawStateValue) {
        if let mockSensorState = (rawState["mockSensorState"] as? MockCGMState.RawValue).flatMap(MockCGMState.init(rawValue:)) {
            self.mockSensorState = mockSensorState
        } else {
            self.mockSensorState = MockCGMState(isStateValid: true, trendType: nil)
        }

        if let dataSource = (rawState["dataSource"] as? MockCGMDataSource.RawValue).flatMap(MockCGMDataSource.init(rawValue:)) {
            self.dataSource = dataSource
        } else {
            self.dataSource = MockCGMDataSource(model: .noData)
        }

        setupGlucoseUpdateTimer()
    }

    deinit {
        glucoseUpdateTimer?.invalidate()
    }

    public var rawState: RawStateValue {
        return [
            "mockSensorState": mockSensorState.rawValue,
            "dataSource": dataSource.rawValue
        ]
    }

    public var appURL: URL? {
        return nil
    }

    public var providesBLEHeartbeat: Bool {
        return false
    }

    public var managedDataInterval: TimeInterval? {
        return nil
    }

    public var shouldSyncToRemoteService: Bool {
        return false
    }

    public func fetchNewDataIfNeeded(_ completion: @escaping (CGMResult) -> Void) {
        dataSource.fetchNewData(completion)
    }

    public func backfillData(datingBack duration: TimeInterval) {
        let now = Date()
        dataSource.backfillData(from: DateInterval(start: now.addingTimeInterval(-duration), end: now)) { result in
            self.cgmManagerDelegate?.cgmManager(self, didUpdateWith: result)
        }
    }

    public func deleteCGMData() {
        cgmManagerDelegate?.dataStore(for: self).deleteGlucoseSamples(fromDevice: MockCGMDataSource.device)
    }

    private func setupGlucoseUpdateTimer() {
        glucoseUpdateTimer = Timer.scheduledTimer(withTimeInterval: .minutes(5), repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.dataSource.fetchNewData { result in
                self.cgmManagerDelegate?.cgmManager(self, didUpdateWith: result)
            }
        }
    }
}

extension MockCGMManager {
    public var debugDescription: String {
        return """
        ## MockCGMManager
        state: \(mockSensorState)
        dataSource: \(dataSource)
        """
    }
}

extension MockCGMState: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        guard let isStateValid = rawValue["isStateValid"] as? Bool else {
            return nil
        }

        self.isStateValid = isStateValid

        if let trendTypeRawValue = rawValue["trendType"] as? GlucoseTrend.RawValue {
            self.trendType = GlucoseTrend(rawValue: trendTypeRawValue)
        }
    }

    public var rawValue: RawValue {
        var rawValue: RawValue = [
            "isStateValid": isStateValid,
        ]

        if let trendType = trendType {
            rawValue["trendType"] = trendType.rawValue
        }

        return rawValue
    }
}

extension MockCGMState: CustomDebugStringConvertible {
    public var debugDescription: String {
        return """
        ## MockCGMState
        * isStateValid: \(isStateValid)
        * trendType: \(trendType.map(String.init(describing:)) ?? "nil")
        """
    }
}
