//
//  MockCGMManager.swift
//  LoopKit
//
//  Created by Michael Pangburn on 11/20/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import HealthKit
import LoopKit
import LoopKitUI // TODO: DeviceStatusBadge references should live in MockKitUI
import LoopTestingKit

public struct MockCGMState: GlucoseDisplayable {
    public var isStateValid: Bool

    public var trendType: GlucoseTrend?

    public var trendRate: HKQuantity?

    public var isLocal: Bool {
        return true
    }
    
    public var glucoseRangeCategory: GlucoseRangeCategory?

    public let unit: HKUnit = .milligramsPerDeciliter

    public var glucoseAlertingEnabled: Bool

    public var samplesShouldBeUploaded: Bool

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
    
    public var cgmStatusBadge: MockCGMStatusBadge?
    
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
    
    public var cgmBatteryChargeRemaining: Double? = 1
    
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
                glucoseRangeCategory: GlucoseRangeCategory? = nil,
                glucoseAlertingEnabled: Bool = false,
                samplesShouldBeUploaded: Bool = false,
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
        self.glucoseRangeCategory = glucoseRangeCategory
        self.glucoseAlertingEnabled = glucoseAlertingEnabled
        self.samplesShouldBeUploaded = samplesShouldBeUploaded
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

public struct MockCGMStatusBadge: DeviceStatusBadge {
    public var image: UIImage? {
        return badgeType.image
    }
    
    public var state: DeviceStatusBadgeState {
        switch badgeType {
        case .lowBattery:
            return .critical
        case .calibrationRequested:
            return .warning
        }
    }
    
    public var badgeType: MockCGMStatusBadgeType
    
    public enum MockCGMStatusBadgeType: Int, CaseIterable {
        case lowBattery
        case calibrationRequested
        
        var image: UIImage? {
            switch self {
            case .lowBattery:
                return UIImage(frameworkImage: "battery.circle.fill")
            case .calibrationRequested:
                return UIImage(frameworkImage: "drop.circle.fill")
            }
        }
    }
    
    init(badgeType: MockCGMStatusBadgeType) {
        self.badgeType = badgeType
    }
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

    public var managerIdentifier: String {
        return MockCGMManager.managerIdentifier
    }
    
    public static let localizedTitle = "CGM Simulator"
    
    public var localizedTitle: String {
        return MockCGMManager.localizedTitle
    }

    public struct MockAlert {
        public let sound: Alert.Sound
        public let identifier: Alert.AlertIdentifier
        public let foregroundContent: Alert.Content
        public let backgroundContent: Alert.Content
        public let interruptionLevel: Alert.InterruptionLevel
    }
    let alerts: [Alert.AlertIdentifier: MockAlert] = [
        submarine.identifier: submarine, buzz.identifier: buzz, critical.identifier: critical, signalLoss.identifier: signalLoss
    ]
    
    public static let submarine = MockAlert(sound: .sound(name: "sub.caf"), identifier: "submarine",
                                            foregroundContent: Alert.Content(title: "Alert: FG Title", body: "Alert: Foreground Body", acknowledgeActionButtonLabel: "FG OK"),
                                            backgroundContent: Alert.Content(title: "Alert: BG Title", body: "Alert: Background Body", acknowledgeActionButtonLabel: "BG OK"),
                                            interruptionLevel: .timeSensitive)
    public static let critical = MockAlert(sound: .sound(name: "critical.caf"), identifier: "critical",
                                           foregroundContent: Alert.Content(title: "Critical Alert: FG Title", body: "Critical Alert: Foreground Body", acknowledgeActionButtonLabel: "Critical FG OK"),
                                           backgroundContent: Alert.Content(title: "Critical Alert: BG Title", body: "Critical Alert: Background Body", acknowledgeActionButtonLabel: "Critical BG OK"),
                                           interruptionLevel: .critical)
    public static let buzz = MockAlert(sound: .vibrate, identifier: "buzz",
                                       foregroundContent: Alert.Content(title: "Alert: FG Title", body: "FG bzzzt", acknowledgeActionButtonLabel: "Buzz"),
                                       backgroundContent: Alert.Content(title: "Alert: BG Title", body: "BG bzzzt", acknowledgeActionButtonLabel: "Buzz"),
                                       interruptionLevel: .active)
    public static let signalLoss = MockAlert(sound: .sound(name: "critical.caf"),
                                             identifier: "signalLoss",
                                             foregroundContent: Alert.Content(title: "Signal Loss", body: "CGM simulator signal loss", acknowledgeActionButtonLabel: "Dismiss"),
                                             backgroundContent: Alert.Content(title: "Signal Loss", body: "CGM simulator signal loss", acknowledgeActionButtonLabel: "Dismiss"),
                                             interruptionLevel: .critical)

    private let lockedMockSensorState = Locked(MockCGMState(isStateValid: true))
    public var mockSensorState: MockCGMState {
        get {
            lockedMockSensorState.value
        }
        set {
            lockedMockSensorState.mutate { $0 = newValue }
            self.notifyStatusObservers(cgmManagerStatus: self.cgmManagerStatus)
        }
    }

    public var glucoseDisplay: GlucoseDisplayable? {
        return mockSensorState
    }
    
    public var cgmManagerStatus: CGMManagerStatus {
        return CGMManagerStatus(hasValidSensorSession: dataSource.isValidSession, lastCommunicationDate: lastCommunicationDate, device: device)
    }

    private var lastCommunicationDate: Date? = nil
    
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

    private let lockedDataSource = Locked(MockCGMDataSource(model: .noData))
    public var dataSource: MockCGMDataSource {
        get {
            lockedDataSource.value
        }
        set {
            lockedDataSource.mutate { $0 = newValue }
            self.notifyStatusObservers(cgmManagerStatus: self.cgmManagerStatus)
        }
    }

    private var glucoseUpdateTimer: Timer?

    public init() {
        setupGlucoseUpdateTimer()
    }

    // MARK: Handling CGM Manager Status observers
    
    private var statusObservers = WeakSynchronizedSet<CGMManagerStatusObserver>()

    public func addStatusObserver(_ observer: CGMManagerStatusObserver, queue: DispatchQueue) {
        statusObservers.insert(observer, queue: queue)
    }

    public func removeStatusObserver(_ observer: CGMManagerStatusObserver) {
        statusObservers.removeElement(observer)
    }
    
    private func notifyStatusObservers(cgmManagerStatus: CGMManagerStatus) {
        delegate.notify { delegate in
            delegate?.cgmManagerDidUpdateState(self)
            delegate?.cgmManager(self, didUpdate: self.cgmManagerStatus)
        }
        statusObservers.forEach { observer in
            observer.cgmManager(self, didUpdate: cgmManagerStatus)
        }
    }
    
    public init?(rawState: RawStateValue) {
        if let mockSensorStateRawValue = rawState["mockSensorState"] as? MockCGMState.RawValue,
            let mockSensorState = MockCGMState(rawValue: mockSensorStateRawValue) {
            self.lockedMockSensorState.value = mockSensorState
        } else {
            self.lockedMockSensorState.value = MockCGMState(isStateValid: true)
        }

        if let dataSourceRawValue = rawState["dataSource"] as? MockCGMDataSource.RawValue,
            let dataSource = MockCGMDataSource(rawValue: dataSourceRawValue) {
            self.lockedDataSource.value = dataSource
        } else {
            self.lockedDataSource.value = MockCGMDataSource(model: .sineCurve(parameters: (baseGlucose: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 110), amplitude: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 20), period: TimeInterval(hours: 6), referenceDate: Date())))
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

    public let isOnboarded = true   // No distinction between created and onboarded

    public let appURL: URL? = nil

    public let providesBLEHeartbeat = false

    public let managedDataInterval: TimeInterval? = nil

    public var shouldSyncToRemoteService: Bool {
        return self.mockSensorState.samplesShouldBeUploaded
    }

    public var healthKitStorageDelayEnabled: Bool {
        get {
            MockCGMManager.healthKitStorageDelay == fixedHealthKitStorageDelay
        }
        set {
            MockCGMManager.healthKitStorageDelay = newValue ? fixedHealthKitStorageDelay : 0
        }
    }

    public let fixedHealthKitStorageDelay: TimeInterval = .minutes(2)
    
    public static var healthKitStorageDelay: TimeInterval = 0
    
    private func logDeviceComms(_ type: DeviceLogEntryType, message: String) {
        self.delegate.delegate?.deviceManager(self, logEventForDeviceIdentifier: "mockcgm", type: type, message: message, completion: nil)
    }

    private func sendCGMReadingResult(_ result: CGMReadingResult) {
        if case .newData(let samples) = result,
            let currentValue = samples.first
        {
            mockSensorState.trendType = currentValue.trend
            mockSensorState.trendRate = currentValue.trendRate
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
        let now = Date()
        logDeviceComms(.send, message: "Fetch new data")
        dataSource.fetchNewData { (result) in
            switch result {
            case .error(let error):
                self.logDeviceComms(.error, message: "Error fetching new data: \(error)")
            case .newData(let samples):
                self.lastCommunicationDate = now
                self.logDeviceComms(.receive, message: "New data received: \(samples)")
            case .unreliableData:
                self.lastCommunicationDate = now
                self.logDeviceComms(.receive, message: "Unreliable data received")
            case .noData:
                self.lastCommunicationDate = now
                self.logDeviceComms(.receive, message: "No new data")
            }
            completion(result)
        }
    }

    public func backfillData(datingBack duration: TimeInterval) {
        let now = Date()
        self.logDeviceComms(.send, message: "backfillData(\(duration))")
        dataSource.backfillData(from: DateInterval(start: now.addingTimeInterval(-duration), end: now)) { result in
            switch result {
            case .error(let error):
                self.logDeviceComms(.error, message: "Backfill error: \(error)")
            case .newData(let samples):
                self.logDeviceComms(.receive, message: "Backfill data: \(samples)")
            case .unreliableData:
                self.logDeviceComms(.receive, message: "Backfill data unreliable")
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
        sendCGMReadingResult(CGMReadingResult.newData(samples.map { NewGlucoseSample($0, device: device) } ))
    }
}

fileprivate extension NewGlucoseSample {
    init(_ other: NewGlucoseSample, device: HKDevice?) {
        self.init(date: other.date,
                  quantity: other.quantity,
                  condition: other.condition,
                  trend: other.trend,
                  trendRate: other.trendRate,
                  isDisplayOnly: other.isDisplayOnly,
                  wasUserEntered: other.wasUserEntered,
                  syncIdentifier: other.syncIdentifier,
                  syncVersion: other.syncVersion,
                  device: device)
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
    
    public func issueAlert(identifier: Alert.AlertIdentifier, trigger: Alert.Trigger, delay: TimeInterval?, metadata: Alert.Metadata? = nil) {
        guard let alert = alerts[identifier] else {
            return
        }
        delegate.notifyDelayed(by: delay ?? 0) { delegate in
            self.logDeviceComms(.delegate, message: "\(#function): \(identifier) \(trigger)")
            delegate?.issueAlert(Alert(identifier: Alert.Identifier(managerIdentifier: self.managerIdentifier, alertIdentifier: identifier),
                                       foregroundContent: alert.foregroundContent,
                                       backgroundContent: alert.backgroundContent,
                                       trigger: trigger,
                                       interruptionLevel: alert.interruptionLevel,
                                       sound: alert.sound,
                                       metadata: metadata))
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
    
    public func acknowledgeAlert(alertIdentifier: Alert.AlertIdentifier, completion: @escaping (Error?) -> Void) {
        self.logDeviceComms(.delegateResponse, message: "\(#function): Alert \(alertIdentifier) acknowledged.")
        completion(nil)
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
    }
    
    private func issueAlert(for glucose: NewGlucoseSample) {
        guard mockSensorState.glucoseAlertingEnabled else {
            return
        }

        let alertTitle: String
        let glucoseAlertIdentifier: String
        let interruptionLevel: Alert.InterruptionLevel
        switch glucose.quantity {
        case ...mockSensorState.urgentLowGlucoseThreshold:
            alertTitle = "Urgent Low Glucose Alert"
            glucoseAlertIdentifier = "glucose.value.low.urgent"
            interruptionLevel = .critical
        case mockSensorState.urgentLowGlucoseThreshold..<mockSensorState.lowGlucoseThreshold:
            alertTitle = "Low Glucose Alert"
            glucoseAlertIdentifier = "glucose.value.low"
            interruptionLevel = .timeSensitive
        case mockSensorState.highGlucoseThreshold...:
            alertTitle = "High Glucose Alert"
            glucoseAlertIdentifier = "glucose.value.high"
            interruptionLevel = .timeSensitive
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
                          trigger: .immediate,
                          interruptionLevel: interruptionLevel)

        delegate.notify { delegate in
            delegate?.issueAlert(alert)
        }
    }
}

//MARK: Device Status Badge stuff

extension MockCGMManager {
    public func requestCalibration(_ requestCalibration: Bool) {
        mockSensorState.cgmStatusBadge = requestCalibration ? MockCGMStatusBadge(badgeType: .calibrationRequested) : nil
        checkAndSetBatteryBadge()
    }
    
    public var cgmBatteryChargeRemaining: Double? {
        get {
            return mockSensorState.cgmBatteryChargeRemaining
        }
        set {
            mockSensorState.cgmBatteryChargeRemaining = newValue
            checkAndSetBatteryBadge()
        }
    }
    
    public var isCalibrationRequested: Bool {
        return mockSensorState.cgmStatusBadge?.badgeType == .calibrationRequested
    }
    
    private func checkAndSetBatteryBadge() {
        // calibration badge is the highest priority
        guard mockSensorState.cgmStatusBadge?.badgeType != .calibrationRequested else {
            return
        }
        
        guard let cgmBatteryChargeRemaining = mockSensorState.cgmBatteryChargeRemaining,
              cgmBatteryChargeRemaining > 0.5 else
        {
            mockSensorState.cgmStatusBadge = MockCGMStatusBadge(badgeType: .lowBattery)
            return
        }
        
        mockSensorState.cgmStatusBadge = nil
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
        self.samplesShouldBeUploaded = rawValue["samplesShouldBeUploaded"] as? Bool ?? false
        self.urgentLowGlucoseThresholdValue = urgentLowGlucoseThresholdValue
        self.lowGlucoseThresholdValue = lowGlucoseThresholdValue
        self.highGlucoseThresholdValue = highGlucoseThresholdValue
        self.cgmLowerLimitValue = cgmLowerLimitValue
        self.cgmUpperLimitValue = cgmUpperLimitValue
        
        if let glucoseRangeCategoryRawValue = rawValue["glucoseRangeCategory"] as? GlucoseRangeCategory.RawValue {
            self.glucoseRangeCategory = GlucoseRangeCategory(rawValue: glucoseRangeCategoryRawValue)
        }
        
        if let localizedMessage = rawValue["localizedMessage"] as? String,
            let alertIdentifier = rawValue["alertIdentifier"] as? Alert.AlertIdentifier
        {
            self.cgmStatusHighlight = MockCGMStatusHighlight(localizedMessage: localizedMessage, alertIdentifier: alertIdentifier)
        }
        
        if let statusBadgeTypeRawValue = rawValue["statusBadgeType"] as? MockCGMStatusBadge.MockCGMStatusBadgeType.RawValue,
           let statusBadgeType = MockCGMStatusBadge.MockCGMStatusBadgeType(rawValue: statusBadgeTypeRawValue)
        {
            self.cgmStatusBadge = MockCGMStatusBadge(badgeType: statusBadgeType)
        }
        
        if let cgmLifecycleProgressRawValue = rawValue["cgmLifecycleProgress"] as? MockCGMLifecycleProgress.RawValue {
            self.cgmLifecycleProgress = MockCGMLifecycleProgress(rawValue: cgmLifecycleProgressRawValue)
        }
        
        self.progressWarningThresholdPercentValue = rawValue["progressWarningThresholdPercentValue"] as? Double
        self.progressCriticalThresholdPercentValue = rawValue["progressCriticalThresholdPercentValue"] as? Double
        self.cgmBatteryChargeRemaining = rawValue["cgmBatteryChargeRemaining"] as? Double
        
        setProgressColor()
    }

    public var rawValue: RawValue {
        var rawValue: RawValue = [
            "isStateValid": isStateValid,
            "glucoseAlertingEnabled": glucoseAlertingEnabled,
            "samplesShouldBeUploaded": samplesShouldBeUploaded,
            "urgentLowGlucoseThresholdValue": urgentLowGlucoseThresholdValue,
            "lowGlucoseThresholdValue": lowGlucoseThresholdValue,
            "highGlucoseThresholdValue": highGlucoseThresholdValue,
            "cgmLowerLimitValue": cgmLowerLimitValue,
            "cgmUpperLimitValue": cgmUpperLimitValue,
        ]

        if let glucoseRangeCategory = glucoseRangeCategory {
            rawValue["glucoseRangeCategory"] = glucoseRangeCategory.rawValue
        }
        
        if let cgmStatusHighlight = cgmStatusHighlight {
            rawValue["localizedMessage"] = cgmStatusHighlight.localizedMessage
            rawValue["alertIdentifier"] = cgmStatusHighlight.alertIdentifier
        }
        
        if let cgmStatusBadgeType = cgmStatusBadge?.badgeType {
            rawValue["statusBadgeType"] = cgmStatusBadgeType.rawValue
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
        
        if let cgmBatteryChargeRemaining = cgmBatteryChargeRemaining {
            rawValue["cgmBatteryChargeRemaining"] = cgmBatteryChargeRemaining
        }
        
        return rawValue
    }
}

extension MockCGMState: CustomDebugStringConvertible {
    public var debugDescription: String {
        return """
        ## MockCGMState
        * isStateValid: \(isStateValid)
        * glucoseAlertingEnabled: \(glucoseAlertingEnabled)
        * samplesShouldBeUploaded: \(samplesShouldBeUploaded)
        * urgentLowGlucoseThresholdValue: \(urgentLowGlucoseThresholdValue)
        * lowGlucoseThresholdValue: \(lowGlucoseThresholdValue)
        * highGlucoseThresholdValue: \(highGlucoseThresholdValue)
        * cgmLowerLimitValue: \(cgmLowerLimitValue)
        * cgmUpperLimitValue: \(cgmUpperLimitValue)
        * highGlucoseThresholdValue: \(highGlucoseThresholdValue)
        * glucoseRangeCategory: \(glucoseRangeCategory as Any)
        * cgmStatusHighlight: \(cgmStatusHighlight as Any)
        * cgmStatusBadge: \(cgmStatusBadge as Any)
        * cgmLifecycleProgress: \(cgmLifecycleProgress as Any)
        * progressWarningThresholdPercentValue: \(progressWarningThresholdPercentValue as Any)
        * progressCriticalThresholdPercentValue: \(progressCriticalThresholdPercentValue as Any)
        * cgmBatteryChargeRemaining: \(cgmBatteryChargeRemaining as Any)
        """
    }
}
