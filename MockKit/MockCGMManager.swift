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
    
    public var glucoseValueType: GlucoseValueType?
    
    private var lowGlucoseThresholdValue: Double

    // HKQuantity isn't codable
    public var lowGlucoseThreshold: HKQuantity {
        get {
            return HKQuantity.init(unit: HKUnit.milligramsPerDeciliter, doubleValue: lowGlucoseThresholdValue)
        }
        set {
            lowGlucoseThresholdValue = newValue.doubleValue(for: HKUnit.milligramsPerDeciliter)
        }
    }

    private var highGlucoseThresholdValue: Double

    // HKQuantity isn't codable
    public var highGlucoseThreshold: HKQuantity {
        get {
            return HKQuantity.init(unit: HKUnit.milligramsPerDeciliter, doubleValue: highGlucoseThresholdValue)
        }
        set {
            highGlucoseThresholdValue = newValue.doubleValue(for: HKUnit.milligramsPerDeciliter)
        }
    }
    
    public var cgmStatusHighlight: MockCGMStatusHighlight?

    public init(isStateValid: Bool = true,
                trendType: GlucoseTrend? = nil,
                glucoseValueType: GlucoseValueType? = nil,
                lowGlucoseThresholdValue: Double = 80,
                highGlucoseThresholdValue: Double = 200,
                cgmStatusHighlight: MockCGMStatusHighlight? = nil)
    {
        self.isStateValid = isStateValid
        self.trendType = trendType
        self.glucoseValueType = glucoseValueType
        self.lowGlucoseThresholdValue = lowGlucoseThresholdValue
        self.highGlucoseThresholdValue = highGlucoseThresholdValue
        self.cgmStatusHighlight = cgmStatusHighlight
    }
}

public struct MockCGMStatusHighlight: DeviceStatusHighlight {
    public var localizedMessage: String
    
    public var icon: UIImage {
        switch alertIdentifier {
        case MockCGMManager.submarine.identifier:
            return UIImage(systemName: "dot.radiowaves.left.and.right")!
        case MockCGMManager.buzz.identifier:
            return UIImage(systemName: "clock")!
        default:
            return UIImage(systemName: "exclamationmark.circle.fill")!
        }
    }
    
    public var color: UIColor {
        switch alertIdentifier {
        case MockCGMManager.submarine.identifier:
            return .systemPurple
        case MockCGMManager.buzz.identifier:
            return .systemOrange
        default:
            return .systemRed
        }
    }
    
    public var alertIdentifier: Alert.AlertIdentifier
}

public final class MockCGMManager: TestingCGMManager {
    
    public static let managerIdentifier = "MockCGMManager"
    public static let localizedTitle = "Simulator"

    public struct MockAlert {
        public let sound: Alert.Sound
        public let identifier: Alert.AlertIdentifier
        public let foregroundContent: Alert.Content
        public let backgroundContent: Alert.Content
    }
    let alerts: [Alert.AlertIdentifier: MockAlert] = [
        submarine.identifier: submarine, buzz.identifier: buzz, critical.identifier: critical
    ]
    
    public static let submarine = MockAlert(sound: .sound(name: "sub.caf"), identifier: "submarine",
                                            foregroundContent: Alert.Content(title: "Alert: FG Title", body: "Alert: Foreground Body", acknowledgeActionButtonLabel: "FG OK"),
                                            backgroundContent: Alert.Content(title: "Alert: BG Title", body: "Alert: Background Body", acknowledgeActionButtonLabel: "BG OK"))
    public static let critical = MockAlert(sound: .sound(name: "critical.caf"), identifier: "critical",
                                           foregroundContent: Alert.Content(title: "Critical Alert: FG Title", body: "Critical Alert: Foreground Body", acknowledgeActionButtonLabel: "Critical FG OK", isCritical: true),
                                           backgroundContent: Alert.Content(title: "Critical Alert: BG Title", body: "Critical Alert: Background Body", acknowledgeActionButtonLabel: "Critical BG OK", isCritical: true))
    public static let buzz = MockAlert(sound: .vibrate, identifier: "buzz",
                                       foregroundContent: Alert.Content(title: "Alert: FG Title", body: "FG bzzzt", acknowledgeActionButtonLabel: "Buzz"),
                                       backgroundContent: Alert.Content(title: "Alert: BG Title", body: "BG bzzzt", acknowledgeActionButtonLabel: "Buzz"))

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
        if case .newData(let samples) = result,
            let currentValue = samples.first
        {
            switch currentValue.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter) {
            case ..<mockSensorState.lowGlucoseThreshold.doubleValue(for: HKUnit.milligramsPerDeciliter):
                mockSensorState.glucoseValueType = .low
            case mockSensorState.lowGlucoseThreshold.doubleValue(for: HKUnit.milligramsPerDeciliter)..<mockSensorState.highGlucoseThreshold.doubleValue(for: HKUnit.milligramsPerDeciliter):
                mockSensorState.glucoseValueType = .normal
            default:
                mockSensorState.glucoseValueType = .high
            }
        }
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
    
    public func updateGlucoseUpdateTimer() {
        glucoseUpdateTimer?.invalidate()
        setupGlucoseUpdateTimer()
    }
    
    private func setupGlucoseUpdateTimer() {
        glucoseUpdateTimer = Timer.scheduledTimer(withTimeInterval: dataSource.dataPointFrequency.frequency, repeats: true) { [weak self] _ in
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
    
    public func getSounds() -> [Alert.Sound] {
        return alerts.map { $1.sound }
    }
    
    public func issueAlert(identifier: Alert.AlertIdentifier, trigger: Alert.Trigger, delay: TimeInterval?) {
        guard let alert = alerts[identifier] else {
            return
        }
        registerBackgroundTask()
        delegate.notifyDelayed(by: delay ?? 0) { delegate in
            self.logDeviceComms(.delegate, message: "\(#function): \(identifier) \(trigger)")
            delegate?.issueAlert(Alert(identifier: Alert.Identifier(managerIdentifier: self.managerIdentifier, alertIdentifier: identifier),
                                       foregroundContent: alert.foregroundContent,
                                       backgroundContent: alert.backgroundContent,
                                       trigger: trigger,
                                       sound: alert.sound))
        }

        // updating the status report
        mockSensorState.cgmStatusHighlight = MockCGMStatusHighlight(localizedMessage: alert.foregroundContent.title, alertIdentifier: alert.identifier)
    }
    
    public func acknowledgeAlert(alertIdentifier: Alert.AlertIdentifier) {
        endBackgroundTask()
        self.logDeviceComms(.delegateResponse, message: "\(#function): Alert \(alertIdentifier) acknowledged.")
    }

    public func retractAlert(identifier: Alert.AlertIdentifier) {
        delegate.notify { $0?.retractAlert(identifier: Alert.Identifier(managerIdentifier: self.managerIdentifier, alertIdentifier: identifier)) }
        // updating the status report
        mockSensorState.cgmStatusHighlight = nil
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
        guard let isStateValid = rawValue["isStateValid"] as? Bool,
            let lowGlucoseThresholdValue = rawValue["lowGlucoseThresholdValue"] as? Double,
            let highGlucoseThresholdValue = rawValue["highGlucoseThresholdValue"] as? Double else
        {
            return nil
        }

        self.isStateValid = isStateValid
        self.lowGlucoseThresholdValue = lowGlucoseThresholdValue
        self.highGlucoseThresholdValue = highGlucoseThresholdValue
        
        if let trendTypeRawValue = rawValue["trendType"] as? GlucoseTrend.RawValue {
            self.trendType = GlucoseTrend(rawValue: trendTypeRawValue)
        }
        
        if let glucoseValueTypeRawValue = rawValue["glucoseValueType"] as? GlucoseValueType.RawValue {
            self.glucoseValueType = GlucoseValueType(rawValue: glucoseValueTypeRawValue)
        }
        
        if let localizedMessage = rawValue["localizedMessage"] as? String,
            let alertIdentifier = rawValue["alertIdentifier"] as? Alert.AlertIdentifier
        {
            self.cgmStatusHighlight = MockCGMStatusHighlight(localizedMessage: localizedMessage, alertIdentifier: alertIdentifier)
        }
    }

    public var rawValue: RawValue {
        var rawValue: RawValue = [
            "isStateValid": isStateValid,
            "lowGlucoseThresholdValue": lowGlucoseThresholdValue,
            "highGlucoseThresholdValue": highGlucoseThresholdValue,
        ]

        if let trendType = trendType {
            rawValue["trendType"] = trendType.rawValue
        }
        
        if let glucoseValueType = glucoseValueType {
            rawValue["glucoseValueType"] = glucoseValueType.rawValue
        }
        
        if let cgmStatusHighlight = cgmStatusHighlight {
            rawValue["localizedMessage"] = cgmStatusHighlight.localizedMessage
            rawValue["alertIdentifier"] = cgmStatusHighlight.alertIdentifier
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
        * lowGlucoseThresholdValue: \(lowGlucoseThresholdValue)
        * highGlucoseThresholdValue: \(highGlucoseThresholdValue)
        * glucoseValueType: \(glucoseValueType as Any)
        * cgmStatusHighlight: \(cgmStatusHighlight as Any)
        """
    }
}
