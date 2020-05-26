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

    public struct MockAlert {
        public let sound: DeviceAlert.Sound
        public let identifier: DeviceAlert.AlertIdentifier
        public let foregroundContent: DeviceAlert.Content
        public let backgroundContent: DeviceAlert.Content
    }
    let alerts: [DeviceAlert.AlertIdentifier: MockAlert] = [
        submarine.identifier: submarine, buzz.identifier: buzz, critical.identifier: critical
    ]
    
    public static let submarine = MockAlert(sound: .sound(name: "sub.caf"), identifier: "submarine",
                                            foregroundContent: DeviceAlert.Content(title: "Alert: FG Title", body: "Alert: Foreground Body", acknowledgeActionButtonLabel: "FG OK"),
                                            backgroundContent: DeviceAlert.Content(title: "Alert: BG Title", body: "Alert: Background Body", acknowledgeActionButtonLabel: "BG OK"))
    public static let critical = MockAlert(sound: .sound(name: "critical.caf"), identifier: "critical",
                                            foregroundContent: DeviceAlert.Content(title: "Critical Alert: FG Title", body: "Critical Alert: Foreground Body", acknowledgeActionButtonLabel: "Critical FG OK", isCritical: true),
                                            backgroundContent: DeviceAlert.Content(title: "Critical Alert: BG Title", body: "Critical Alert: Background Body", acknowledgeActionButtonLabel: "Critical BG OK", isCritical: true))
    public static let buzz = MockAlert(sound: .vibrate, identifier: "buzz",
                                       foregroundContent: DeviceAlert.Content(title: "Alert: FG Title", body: "FG bzzzt", acknowledgeActionButtonLabel: "Buzz"),
                                       backgroundContent: DeviceAlert.Content(title: "Alert: BG Title", body: "BG bzzzt", acknowledgeActionButtonLabel: "Buzz"))

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

    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

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

    private func logDeviceComms(_ type: DeviceLogEntryType, message: String) {
        delegate.notify { (delegate) in
            delegate?.deviceManager(self, logEventForDeviceIdentifier: "mockcgm", type: type, message: message, completion: nil)
        }
    }

    private func sendCGMResult(_ result: CGMResult) {
        self.delegate.notify { delegate in
            delegate?.cgmManager(self, didUpdateWith: result)
        }
    }

    public func fetchNewDataIfNeeded(_ completion: @escaping (CGMResult) -> Void) {
        logDeviceComms(.send, message: "Fetch new data")
        dataSource.fetchNewData { (result) in
            switch result {
            case .error(let error):
                self.logDeviceComms(.error, message: "Error fetching new data: \(error)")
            case .newData(let samples):
                self.logDeviceComms(.receive, message: "New data received: \(samples)")
            case .noData:
                self.logDeviceComms(.receive, message: "No new data")
            }
            completion(result)
        }
    }

    public func backfillData(datingBack duration: TimeInterval) {
        let now = Date()
        dataSource.backfillData(from: DateInterval(start: now.addingTimeInterval(-duration), end: now)) { result in
            switch result {
            case .error(let error):
                self.logDeviceComms(.error, message: "Backfill error: \(error)")
            case .newData(let samples):
                self.logDeviceComms(.receive, message: "Backfill data: \(samples)")
            case .noData:
                self.logDeviceComms(.receive, message: "Backfill empty")
            }
            self.sendCGMResult(result)
        }
    }
    
    private func setupGlucoseUpdateTimer() {
        glucoseUpdateTimer = Timer.scheduledTimer(withTimeInterval: dataSource.dataPointFrequency, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.fetchNewDataIfNeeded() { result in
                self.sendCGMResult(result)
            }
        }
    }

    public func injectGlucoseSamples(_ samples: [NewGlucoseSample]) {
        guard !samples.isEmpty else { return }
        var samples = samples
        samples.mutateEach { $0.device = device }
        sendCGMResult(CGMResult.newData(samples))
    }
}

// MARK: Alert Stuff

extension MockCGMManager {
    
    public func getSoundBaseURL() -> URL? {
        return Bundle(for: type(of: self)).bundleURL
    }
    
    public func getSounds() -> [DeviceAlert.Sound] {
        return alerts.map { $1.sound }
    }
    
    public func issueAlert(identifier: DeviceAlert.AlertIdentifier, trigger: DeviceAlert.Trigger, delay: TimeInterval?) {
        guard let alert = alerts[identifier] else {
            return
        }
        registerBackgroundTask()
        delegate.notifyDelayed(by: delay ?? 0) { delegate in
            self.logDeviceComms(.delegate, message: "\(#function): \(identifier) \(trigger)")
            delegate?.issueAlert(DeviceAlert(identifier: DeviceAlert.Identifier(managerIdentifier: self.managerIdentifier, alertIdentifier: identifier),
                                             foregroundContent: alert.foregroundContent,
                                             backgroundContent: alert.backgroundContent,
                                             trigger: trigger,
                                             sound: alert.sound))
        }
    }
    
    public func acknowledgeAlert(alertIdentifier: DeviceAlert.AlertIdentifier) {
        endBackgroundTask()
        self.logDeviceComms(.delegateResponse, message: "\(#function): Alert \(alertIdentifier) acknowledged.")
    }

    public func retractAlert(identifier: DeviceAlert.AlertIdentifier) {
        delegate.notify { $0?.retractAlert(identifier: DeviceAlert.Identifier(managerIdentifier: self.managerIdentifier, alertIdentifier: identifier)) }
    }
    
    private func registerBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        assert(backgroundTask != .invalid)
    }
    
    private func endBackgroundTask() {
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
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
