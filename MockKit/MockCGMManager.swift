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

public struct MockCGMState: GlucoseDisplayable {
    public var isStateValid: Bool

    public var trendType: GlucoseTrend?

    public var isLocal: Bool {
        return true
    }
    
    public var glucoseRangeCategory: GlucoseRangeCategory?

    public let unit: HKUnit = .milligramsPerDeciliter

    public var glucoseAlertingEnabled: Bool

    private var cgmLowerLimitValue: Double
       
    // HKQuantity isn't codable
    public var cgmLowerLimit: HKQuantity {
        get {
            return HKQuantity.init(unit: unit, doubleValue: cgmLowerLimitValue)
        }
        set {
            var newDoubleValue = newValue.doubleValue(for: unit)
            if newDoubleValue >= urgentLowGlucoseThresholdValue {
                newDoubleValue = urgentLowGlucoseThresholdValue - 1
            }
            cgmLowerLimitValue = newDoubleValue
        }
    }
    
    private var urgentLowGlucoseThresholdValue: Double
    
    public var urgentLowGlucoseThreshold: HKQuantity {
        get {
            return HKQuantity.init(unit: unit, doubleValue: urgentLowGlucoseThresholdValue)
        }
        set {
            var newDoubleValue = newValue.doubleValue(for: unit)
            if newDoubleValue <= cgmLowerLimitValue {
                newDoubleValue = cgmLowerLimitValue + 1
            }
            if newDoubleValue >= lowGlucoseThresholdValue {
                newDoubleValue = lowGlucoseThresholdValue - 1
            }
            urgentLowGlucoseThresholdValue = newDoubleValue
        }
    }
    
    private var lowGlucoseThresholdValue: Double

    public var lowGlucoseThreshold: HKQuantity {
        get {
            return HKQuantity.init(unit: unit, doubleValue: lowGlucoseThresholdValue)
        }
        set {
            var newDoubleValue = newValue.doubleValue(for: unit)
            if newDoubleValue <= urgentLowGlucoseThresholdValue {
                newDoubleValue = urgentLowGlucoseThresholdValue + 1
            }
            if newDoubleValue >= highGlucoseThresholdValue {
                newDoubleValue = highGlucoseThresholdValue - 1
            }
            lowGlucoseThresholdValue = newDoubleValue
        }
    }

    private var highGlucoseThresholdValue: Double

    public var highGlucoseThreshold: HKQuantity {
        get {
            return HKQuantity.init(unit: unit, doubleValue: highGlucoseThresholdValue)
        }
        set {
            var newDoubleValue = newValue.doubleValue(for: unit)
            if newDoubleValue <= lowGlucoseThresholdValue {
                newDoubleValue = lowGlucoseThresholdValue + 1
            }
            if newDoubleValue >= cgmUpperLimitValue {
                newDoubleValue = cgmUpperLimitValue - 1
            }
            highGlucoseThresholdValue = newDoubleValue
        }
    }
    
    private var cgmUpperLimitValue: Double
    
    public var cgmUpperLimit: HKQuantity {
        get {
            return HKQuantity.init(unit: unit, doubleValue: cgmUpperLimitValue)
        }
        set {
            var newDoubleValue = newValue.doubleValue(for: unit)
            if newDoubleValue <= highGlucoseThresholdValue {
                newDoubleValue = highGlucoseThresholdValue + 1
            }
            cgmUpperLimitValue = newDoubleValue
        }
    }
    
    public var cgmStatusHighlight: MockCGMStatusHighlight?
    
    public var cgmLifecycleProgress: MockCGMLifecycleProgress? {
        didSet {
            if cgmLifecycleProgress != oldValue {
                setProgressColor()
            }
        }
    }
    
    public var progressWarningThresholdPercentValue: Double? {
        didSet {
            if progressWarningThresholdPercentValue != oldValue {
                setProgressColor()
            }
        }
    }
    
    public var progressCriticalThresholdPercentValue: Double? {
        didSet {
            if progressCriticalThresholdPercentValue != oldValue {
                setProgressColor()
            }
        }
    }
    
    private mutating func setProgressColor() {
        guard var cgmLifecycleProgress = cgmLifecycleProgress else {
            return
        }
        
        if let progressCriticalThresholdPercentValue = progressCriticalThresholdPercentValue,
            cgmLifecycleProgress.percentComplete >= progressCriticalThresholdPercentValue
        {
            cgmLifecycleProgress.progressState = .critical
        } else if let progressWarningThresholdPercentValue = progressWarningThresholdPercentValue,
            cgmLifecycleProgress.percentComplete >= progressWarningThresholdPercentValue
        {
            cgmLifecycleProgress.progressState = .warning
        } else {
            cgmLifecycleProgress.progressState = .normalCGM
        }
        
        self.cgmLifecycleProgress = cgmLifecycleProgress
    }
    
    public init(isStateValid: Bool = true,
                trendType: GlucoseTrend? = nil,
                glucoseRangeCategory: GlucoseRangeCategory? = nil,
                glucoseAlertingEnabled: Bool = false,
                urgentLowGlucoseThresholdValue: Double = 55,
                lowGlucoseThresholdValue: Double = 80,
                highGlucoseThresholdValue: Double = 200,
                cgmLowerLimitValue: Double = 40,
                cgmUpperLimitValue: Double = 400,
                cgmStatusHighlight: MockCGMStatusHighlight? = nil,
                cgmLifecycleProgress: MockCGMLifecycleProgress? = nil,
                progressWarningThresholdPercentValue: Double? = nil,
                progressCriticalThresholdPercentValue: Double? = nil)
    {
        self.isStateValid = isStateValid
        self.trendType = trendType
        self.glucoseRangeCategory = glucoseRangeCategory
        self.glucoseAlertingEnabled = glucoseAlertingEnabled
        self.urgentLowGlucoseThresholdValue = urgentLowGlucoseThresholdValue
        self.lowGlucoseThresholdValue = lowGlucoseThresholdValue
        self.highGlucoseThresholdValue = highGlucoseThresholdValue
        self.cgmLowerLimitValue = cgmLowerLimitValue
        self.cgmUpperLimitValue = cgmUpperLimitValue
        self.cgmStatusHighlight = cgmStatusHighlight
        self.cgmLifecycleProgress = cgmLifecycleProgress
        self.progressWarningThresholdPercentValue = progressWarningThresholdPercentValue
        self.progressCriticalThresholdPercentValue = progressCriticalThresholdPercentValue
        setProgressColor()
    }
}

public struct MockCGMStatusHighlight: DeviceStatusHighlight {
    public var localizedMessage: String
    
    public var imageName: String {
        switch alertIdentifier {
        case MockCGMManager.submarine.identifier:
            return "dot.radiowaves.left.and.right"
        case MockCGMManager.buzz.identifier:
            return "clock"
        default:
            return "exclamationmark.circle.fill"
        }
    }
    
    public var state: DeviceStatusHighlightState{
        switch alertIdentifier {
        case MockCGMManager.submarine.identifier:
            return .normalCGM
        case MockCGMManager.buzz.identifier:
            return .warning
        default:
            return .critical
        }
    }
    
    public var alertIdentifier: Alert.AlertIdentifier
}

public struct MockCGMLifecycleProgress: DeviceLifecycleProgress, Equatable {
    public var percentComplete: Double
    
    public var progressState: DeviceLifecycleProgressState
        
    public init(percentComplete: Double, progressState: DeviceLifecycleProgressState = .normalCGM) {
        self.percentComplete = percentComplete
        self.progressState = progressState
    }
}

extension MockCGMLifecycleProgress: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        guard let percentComplete = rawValue["percentComplete"] as? Double,
            let progressStateRawValue = rawValue["progressState"] as? DeviceLifecycleProgressState.RawValue,
            let progressState = DeviceLifecycleProgressState(rawValue: progressStateRawValue) else
        {
            return nil
        }

        self.percentComplete = percentComplete
        self.progressState = progressState
    }

    public var rawValue: RawValue {
        let rawValue: RawValue = [
            "percentComplete": percentComplete,
            "progressState": progressState.rawValue,
        ]

        return rawValue
    }
}

public final class MockCGMManager: TestingCGMManager {
    
    public static let managerIdentifier = "MockCGMManager"
    public static let localizedTitle = "CGM Simulator"

    public struct MockAlert {
        public let sound: Alert.Sound
        public let identifier: Alert.AlertIdentifier
        public let foregroundContent: Alert.Content
        public let backgroundContent: Alert.Content
    }
    let alerts: [Alert.AlertIdentifier: MockAlert] = [
        submarine.identifier: submarine, buzz.identifier: buzz, critical.identifier: critical, signalLoss.identifier: signalLoss
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
    public static let signalLoss = MockAlert(sound: .sound(name: "critical.caf"),
                                             identifier: "signalLoss",
                                             foregroundContent: Alert.Content(title: "Signal Loss", body: "CGM simulator signal loss", acknowledgeActionButtonLabel: "Dismiss"),
                                             backgroundContent: Alert.Content(title: "Signal Loss", body: "CGM simulator signal loss", acknowledgeActionButtonLabel: "Dismiss"))

    public var mockSensorState: MockCGMState {
        didSet {
            delegate.notify { (delegate) in
                delegate?.cgmManagerDidUpdateState(self)
            }
        }
    }

    public var glucoseDisplay: GlucoseDisplayable? {
        return mockSensorState
    }
    
    public var cgmStatus: CGMManagerStatus {
        return CGMManagerStatus(hasValidSensorSession: dataSource.isValidSession)
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
                delegate?.cgmManager(self, didUpdate: self.cgmStatus)
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
    
    private func logDeviceCommunication(_ message: String, type: DeviceLogEntryType = .send) {
        self.delegate.notify { (delegate) in
            delegate?.deviceManager(self, logEventForDeviceIdentifier: "MockId", type: type, message: message, completion: nil)
        }
    }

    private func logDeviceComms(_ type: DeviceLogEntryType, message: String) {
        delegate.notify { (delegate) in
            delegate?.deviceManager(self, logEventForDeviceIdentifier: "mockcgm", type: type, message: message, completion: nil)
        }
    }

    private func sendCGMReadingResult(_ result: CGMReadingResult) {
        if case .newData(let samples) = result,
            let currentValue = samples.first
        {
            mockSensorState.glucoseRangeCategory = glucoseRangeCategory(for: currentValue.quantitySample)
            issueAlert(for: currentValue)
        }
        self.delegate.notify { delegate in
            delegate?.cgmManager(self, hasNew: result)
        }
    }
    
    public func glucoseRangeCategory(for glucose: GlucoseSampleValue) -> GlucoseRangeCategory? {
        switch glucose.quantity {
        case ...mockSensorState.cgmLowerLimit:
            return glucose.wasUserEntered ? .urgentLow : .belowRange
        case mockSensorState.cgmLowerLimit..<mockSensorState.urgentLowGlucoseThreshold:
            return .urgentLow
        case mockSensorState.urgentLowGlucoseThreshold..<mockSensorState.lowGlucoseThreshold:
            return .low
        case mockSensorState.lowGlucoseThreshold..<mockSensorState.highGlucoseThreshold:
            return .normal
        case mockSensorState.highGlucoseThreshold..<mockSensorState.cgmUpperLimit:
            return .high
        default:
            return glucose.wasUserEntered ? .high : .aboveRange
        }
    }

    public func fetchNewDataIfNeeded(_ completion: @escaping (CGMReadingResult) -> Void) {
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
        self.logDeviceCommunication("backfillData(\(duration))")
        dataSource.backfillData(from: DateInterval(start: now.addingTimeInterval(-duration), end: now)) { result in
            switch result {
            case .error(let error):
                self.logDeviceComms(.error, message: "Backfill error: \(error)")
            case .newData(let samples):
                self.logDeviceComms(.receive, message: "Backfill data: \(samples)")
            case .noData:
                self.logDeviceComms(.receive, message: "Backfill empty")
            }
            self.sendCGMReadingResult(result)
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
                self.sendCGMReadingResult(result)
            }
        }
    }

    public func injectGlucoseSamples(_ samples: [NewGlucoseSample]) {
        guard !samples.isEmpty else { return }
        var samples = samples
        samples.mutateEach { $0.device = device }
        sendCGMReadingResult(CGMReadingResult.newData(samples))
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

    public var hasRetractableAlert: Bool {
        // signal loss alerts can only be removed by switching the CGM data source
        return currentAlertIdentifier != nil && currentAlertIdentifier != MockCGMManager.signalLoss.identifier
    }

    public var currentAlertIdentifier: Alert.AlertIdentifier? {
        return mockSensorState.cgmStatusHighlight?.alertIdentifier
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

        // updating the status highlight
        setStatusHighlight(MockCGMStatusHighlight(localizedMessage: alert.foregroundContent.title, alertIdentifier: alert.identifier))
    }
    
    public func issueSignalLossAlert() {
        issueAlert(identifier: MockCGMManager.signalLoss.identifier, trigger: .immediate, delay: nil)
    }
    
    public func retractSignalLossAlert() {
        retractAlert(identifier: MockCGMManager.signalLoss.identifier)
    }
    
    public func acknowledgeAlert(alertIdentifier: Alert.AlertIdentifier) {
        endBackgroundTask()
        self.logDeviceComms(.delegateResponse, message: "\(#function): Alert \(alertIdentifier) acknowledged.")
    }

    public func retractCurrentAlert() {
        guard hasRetractableAlert, let identifier = currentAlertIdentifier else { return }

        retractAlert(identifier: identifier)
    }

    public func retractAlert(identifier: Alert.AlertIdentifier) {
        delegate.notify { $0?.retractAlert(identifier: Alert.Identifier(managerIdentifier: self.managerIdentifier, alertIdentifier: identifier)) }
        
        // updating the status highlight
        if  mockSensorState.cgmStatusHighlight?.alertIdentifier == identifier {
            setStatusHighlight(nil)
        }
    }
    
    public func setStatusHighlight(_ statusHighlight: MockCGMStatusHighlight?) {
        mockSensorState.cgmStatusHighlight = statusHighlight
        
        if statusHighlight == nil,
            case .signalLoss = dataSource.model
        {
            // restore signal loss status highlight
            issueSignalLossAlert()
        }

        // trigger display of the status highlight
        sendCGMReadingResult(.noData)
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

    private func issueAlert(for glucose: NewGlucoseSample) {
        guard mockSensorState.glucoseAlertingEnabled else {
            return
        }

        let alertTitle: String
        let glucoseAlertIdentifier: String
        switch glucose.quantity {
        case ...mockSensorState.urgentLowGlucoseThreshold:
            alertTitle = "Urgent Low Glucose Alert"
            glucoseAlertIdentifier = "glucose.value.low.urgent"
        case mockSensorState.urgentLowGlucoseThreshold..<mockSensorState.lowGlucoseThreshold:
            alertTitle = "Low Glucose Alert"
            glucoseAlertIdentifier = "glucose.value.low"
        case mockSensorState.highGlucoseThreshold...:
            alertTitle = "High Glucose Alert"
            glucoseAlertIdentifier = "glucose.value.high"
        default:
            return
        }

        let alertIdentifier = Alert.Identifier(managerIdentifier: self.managerIdentifier,
                                               alertIdentifier: glucoseAlertIdentifier)
        let alertContent = Alert.Content(title: alertTitle,
                                         body: "The glucose measurement received triggered this alert",
                                         acknowledgeActionButtonLabel: "Dismiss")
        let alert = Alert(identifier: alertIdentifier,
                          foregroundContent: alertContent,
                          backgroundContent: alertContent,
                          trigger: .immediate)

        delegate.notify { delegate in
            delegate?.issueAlert(alert)
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
        guard let isStateValid = rawValue["isStateValid"] as? Bool,
            let glucoseAlertingEnabled = rawValue["glucoseAlertingEnabled"] as? Bool,
            let urgentLowGlucoseThresholdValue = rawValue["urgentLowGlucoseThresholdValue"] as? Double,
            let lowGlucoseThresholdValue = rawValue["lowGlucoseThresholdValue"] as? Double,
            let highGlucoseThresholdValue = rawValue["highGlucoseThresholdValue"] as? Double,
            let cgmLowerLimitValue = rawValue["cgmLowerLimitValue"] as? Double,
            let cgmUpperLimitValue = rawValue["cgmUpperLimitValue"] as? Double else
        {
            return nil
        }

        self.isStateValid = isStateValid
        self.glucoseAlertingEnabled = glucoseAlertingEnabled
        self.urgentLowGlucoseThresholdValue = urgentLowGlucoseThresholdValue
        self.lowGlucoseThresholdValue = lowGlucoseThresholdValue
        self.highGlucoseThresholdValue = highGlucoseThresholdValue
        self.cgmLowerLimitValue = cgmLowerLimitValue
        self.cgmUpperLimitValue = cgmUpperLimitValue
        
        if let trendTypeRawValue = rawValue["trendType"] as? GlucoseTrend.RawValue {
            self.trendType = GlucoseTrend(rawValue: trendTypeRawValue)
        }
        
        if let glucoseRangeCategoryRawValue = rawValue["glucoseRangeCategory"] as? GlucoseRangeCategory.RawValue {
            self.glucoseRangeCategory = GlucoseRangeCategory(rawValue: glucoseRangeCategoryRawValue)
        }
        
        if let localizedMessage = rawValue["localizedMessage"] as? String,
            let alertIdentifier = rawValue["alertIdentifier"] as? Alert.AlertIdentifier
        {
            self.cgmStatusHighlight = MockCGMStatusHighlight(localizedMessage: localizedMessage, alertIdentifier: alertIdentifier)
        }
        
        if let cgmLifecycleProgressRawValue = rawValue["cgmLifecycleProgress"] as? MockCGMLifecycleProgress.RawValue {
            self.cgmLifecycleProgress = MockCGMLifecycleProgress(rawValue: cgmLifecycleProgressRawValue)
        }
        
        self.progressWarningThresholdPercentValue = rawValue["progressWarningThresholdPercentValue"] as? Double
        self.progressCriticalThresholdPercentValue = rawValue["progressCriticalThresholdPercentValue"] as? Double
        
        setProgressColor()
    }

    public var rawValue: RawValue {
        var rawValue: RawValue = [
            "isStateValid": isStateValid,
            "glucoseAlertingEnabled": glucoseAlertingEnabled,
            "urgentLowGlucoseThresholdValue": urgentLowGlucoseThresholdValue,
            "lowGlucoseThresholdValue": lowGlucoseThresholdValue,
            "highGlucoseThresholdValue": highGlucoseThresholdValue,
            "cgmLowerLimitValue": cgmLowerLimitValue,
            "cgmUpperLimitValue": cgmUpperLimitValue,
        ]

        if let trendType = trendType {
            rawValue["trendType"] = trendType.rawValue
        }
        
        if let glucoseRangeCategory = glucoseRangeCategory {
            rawValue["glucoseRangeCategory"] = glucoseRangeCategory.rawValue
        }
        
        if let cgmStatusHighlight = cgmStatusHighlight {
            rawValue["localizedMessage"] = cgmStatusHighlight.localizedMessage
            rawValue["alertIdentifier"] = cgmStatusHighlight.alertIdentifier
        }
        
        if let cgmLifecycleProgress = cgmLifecycleProgress {
            rawValue["cgmLifecycleProgress"] = cgmLifecycleProgress.rawValue
        }
        
        if let progressWarningThresholdPercentValue = progressWarningThresholdPercentValue {
            rawValue["progressWarningThresholdPercentValue"] = progressWarningThresholdPercentValue
        }
        
        if let progressCriticalThresholdPercentValue = progressCriticalThresholdPercentValue {
            rawValue["progressCriticalThresholdPercentValue"] = progressCriticalThresholdPercentValue
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
        * glucoseAlertingEnabled: \(glucoseAlertingEnabled)
        * urgentLowGlucoseThresholdValue: \(urgentLowGlucoseThresholdValue)
        * lowGlucoseThresholdValue: \(lowGlucoseThresholdValue)
        * highGlucoseThresholdValue: \(highGlucoseThresholdValue)
        * cgmLowerLimitValue: \(cgmLowerLimitValue)
        * cgmUpperLimitValue: \(cgmUpperLimitValue)
        * highGlucoseThresholdValue: \(highGlucoseThresholdValue)
        * glucoseRangeCategory: \(glucoseRangeCategory as Any)
        * cgmStatusHighlight: \(cgmStatusHighlight as Any)
        * cgmLifecycleProgress: \(cgmLifecycleProgress as Any)
        * progressWarningThresholdPercentValue: \(progressWarningThresholdPercentValue as Any)
        * progressCriticalThresholdPercentValue: \(progressCriticalThresholdPercentValue as Any)
        """
    }
}
