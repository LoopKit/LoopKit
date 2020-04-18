//
//  MockCGMManager.swift
//  LoopKit
//
//  Created by Michael Pangburn on 11/20/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import HealthKit
import LoopKit
import LoopTestingKit


public struct MockCGMState: SensorDisplayable {
    public var isStateValid: Bool

    public var trendType: GlucoseTrend?

    public var isLocal: Bool {
        return true
    }
}

public final class MockCGMManager: TestingCGMManager {
    public static let managerIdentifier = "MockCGMManager"
    public static let localizedTitle = "Simulator"

    public var mockSensorState: MockCGMState {
        didSet {
            delegate.notify { (delegate) in
                delegate?.cgmManagerDidUpdateState(self)
            }
        }
    }

    public var sensorState: SensorDisplayable? {
        return mockSensorState
    }

    public var testingDevice: HKDevice {
        return MockCGMDataSource.device
    }

    public var device: HKDevice? {
        return testingDevice
    }

    public weak var cgmManagerDelegate: CGMManagerDelegate? {
        get {
            return delegate.delegate
        }
        set {
            delegate.delegate = newValue
        }
    }

    public var delegateQueue: DispatchQueue! {
        get {
            return delegate.queue
        }
        set {
            delegate.queue = newValue
        }
    }

    private let delegate = WeakSynchronizedDelegate<CGMManagerDelegate>()

    public var dataSource: MockCGMDataSource {
        didSet {
            delegate.notify { (delegate) in
                delegate?.cgmManagerDidUpdateState(self)
            }
        }
    }

    private var glucoseUpdateTimer: Timer?

    public init?(rawState: RawStateValue) {
        if let mockSensorStateRawValue = rawState["mockSensorState"] as? MockCGMState.RawValue,
            let mockSensorState = MockCGMState(rawValue: mockSensorStateRawValue) {
            self.mockSensorState = mockSensorState
        } else {
            self.mockSensorState = MockCGMState(isStateValid: true, trendType: nil)
        }

        if let dataSourceRawValue = rawState["dataSource"] as? MockCGMDataSource.RawValue,
            let dataSource = MockCGMDataSource(rawValue: dataSourceRawValue) {
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

    public let appURL: URL? = nil

    public let providesBLEHeartbeat = false

    public let managedDataInterval: TimeInterval? = nil

    public let shouldSyncToRemoteService = false
    
    private func logDeviceCommunication(_ message: String, type: DeviceLogEntryType = .send) {
        self.delegate.notify { (delegate) in
            delegate?.deviceManager(self, logEventForDeviceIdentifier: "MockId", type: type, message: message, completion: nil)
        }
    }

    public func fetchNewDataIfNeeded(_ completion: @escaping (CGMResult) -> Void) {
        dataSource.fetchNewData(completion)
    }

    public func backfillData(datingBack duration: TimeInterval) {
        let now = Date()
        self.logDeviceCommunication("backfillData(\(duration))")
        dataSource.backfillData(from: DateInterval(start: now.addingTimeInterval(-duration), end: now)) { result in
            self.logDeviceCommunication("backfillData received (\(result))", type: .receive)
            self.delegate.notify { delegate in
                delegate?.cgmManager(self, didUpdateWith: result)
            }
        }
    }
    
    private func setupGlucoseUpdateTimer() {
        glucoseUpdateTimer = Timer.scheduledTimer(withTimeInterval: dataSource.dataPointFrequency, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.dataSource.fetchNewData { result in
                self.logDeviceCommunication("updated data: \(result)", type: .receive)
                self.delegate.notify { delegate in
                    delegate?.cgmManager(self, didUpdateWith: result)
                }
            }
        }
    }

    public func injectGlucoseSamples(_ samples: [NewGlucoseSample]) {
        guard !samples.isEmpty else { return }
        var samples = samples
        samples.mutateEach { $0.device = device }
        let result = CGMResult.newData(samples)
        delegate.notify { delegate in
            delegate?.cgmManager(self, didUpdateWith: result)
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
        * trendType: \(trendType as Any)
        """
    }
}
