//
//  MockPumpManagerSettingsViewModel.swift
//  MockKitUI
//
//  Created by Nathaniel Hamming on 2023-05-18.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI
import MockKit
import LoopAlgorithm

@MainActor
class MockPumpManagerSettingsViewModel: ObservableObject {
    let pumpManager: MockPumpManager
    
    var isDeliverySuspended: Bool {
        switch pumpManager.status.basalDeliveryState {
        case .suspended:
            return true
        default:
            return false
        }
    }
    
    var insulinDeliveryDisabled: Bool {
        pumpManager.state.insulinDeliveryDisabled
    }

    @Published private(set) var transitioningSuspendResumeInsulinDelivery = false
    
    @Published var suspendedAt: Date?
    
    var suspendedAtString: String? {
        guard let suspendedAt = suspendedAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: suspendedAt)
    }
    
    var suspendReminderDelayOptions: [TimeInterval] {
        [.minutes(30), .hours(1), .hours(1.5), .hours(2)]
    }
    
    var suspendResumeInsulinDeliveryLabel: String {
        if isDeliverySuspended {
            return "Tap to Resume Insulin Delivery"
        } else {
            return "Suspend Insulin Delivery"
        }
    }
    
    lazy var suspendReminderTimeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.hour, .minute]
        return formatter
    }()
    
    static private let dateTimeFormatter: DateFormatter = {
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .short
        timeFormatter.timeStyle = .short
        return timeFormatter
    }()
    
    static private let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    @Published private var statusHighlight: DeviceStatusHighlight?
    var pumpStatusHighlight: DeviceStatusHighlight? {
        let shouldShowStatusHighlight = !(isDeliverySuspended && !insulinDeliveryDisabled) || !(statusHighlight?.localizedMessage.contains("Suspend") == true) // do not show the insulin suspended status highlight
        
        return shouldShowStatusHighlight ? statusHighlight : nil
    }

    static private let basalRateFormatter: QuantityFormatter = {
        QuantityFormatter(for: .internationalUnitsPerHour)
    }()

    private var pumpPairedInterval: TimeInterval {
        pumpExpirationRemaing - pumpLifeTime
    }
    
    var lastPumpPairedDateTimeString: String {
        Self.dateTimeFormatter.string(from: Date().addingTimeInterval(pumpPairedInterval))
    }

    private let pumpExpirationRemaing = TimeInterval(days: 2.0)
    private let pumpLifeTime = TimeInterval(days: 3.0)
    var pumpExpirationPercentComplete: Double {
        (pumpLifeTime - pumpExpirationRemaing) / pumpLifeTime
    }

    var pumpExpirationDateTimeString: String {
        Self.dateTimeFormatter.string(from: Date().addingTimeInterval(pumpExpirationRemaing))
    }

    var currentBasalRate: String {
        guard let currentBasalRate = pumpManager.currentBasalRate else { return "-" }
        return Self.basalRateFormatter.string(from: currentBasalRate) ?? "-"
    }


    var pumpTimeString: String {
        Self.shortTimeFormatter.string(from: Date())
    }
    
    @Published private(set) var basalDeliveryState: PumpManagerStatus.BasalDeliveryState? {
        didSet {
            setSuspenededAtString()
        }
    }

    @Published private(set) var basalDeliveryRate: Double?
    
    @Published private(set) var basalDeliveryRateDate: Date?
    var basalDeliveryRateDateString: String? {
        guard let basalDeliveryRateDate else { return nil }
        return Self.shortTimeFormatter.string(from: basalDeliveryRateDate)
    }
    
    @Published private(set) var automatedTreatmentState: AutomatedTreatmentState
    var basalDisplayStateString: String {
        switch automatedTreatmentState {
        case .neutralOverride:
            return LocalizedString("Preset\nDelivery", comment: "Label for neutral basal with override")
        case .neutralNoOverride:
            return LocalizedString("Scheduled\nBasal", comment: "Label for neutral basal without override")
        case .increasedInsulin:
            return LocalizedString("Increased\nDelivery", comment: "Label for when temp basal is above the neutral basal")
        default:
            return LocalizedString("Decreased\nDelivery", comment: "Label for when temp basal is below the neutral basal")
        }
    }

    @Published private(set) var presentDeliveryWarning: Bool?
    
    var isScheduledBasal: Bool {
        switch basalDeliveryState {
        case .active, .initiatingTempBasal:
            return true
        default:
            return false
        }
    }
    
    var isTempBasal: Bool {
        switch basalDeliveryState {
        case .tempBasal, .cancelingTempBasal:
            return true
        default:
            return false
        }
    }
    
    static let reservoirVolumeFormatter: QuantityFormatter = {
        let formatter = QuantityFormatter(for: .internationalUnit)
        formatter.numberFormatter.maximumFractionDigits = 2
        formatter.avoidLineBreaking = true
        return formatter
    }()
    
    var reservoirLevelString: String {
        let reservoirUnitsRemaining = pumpManager.state.reservoirUnitsRemaining
        let formatter = Self.reservoirVolumeFormatter
        formatter.numberFormatter.maximumFractionDigits = 2
        formatter.numberFormatter.minimumFractionDigits = 0
        let quantity = LoopQuantity(unit: .internationalUnit, doubleValue: reservoirUnitsRemaining)
        
        switch pumpManager.state.reservoirUnitsRemaining {
        case let x where x >= 50:
            // when above the rounding limit, do not display fractions
            return "50+"
        default:
            return formatter.string(from: quantity, includeUnit: false) ?? ""
        }
    }
    
    var reservoirAccuracyString: String {
        pumpManager.state.reservoirUnitsRemaining >= 50 ? "Estimated Reading" : "Accurate Reading"
    }
    
    init(pumpManager: MockPumpManager) {
        self.pumpManager = pumpManager
        self.canSynchronizePumpTime = pumpManager.canSynchronizePumpTime
        self.detectedSystemTimeOffset = pumpManager.detectedSystemTimeOffset
        self.statusHighlight = pumpManager.pumpStatusHighlight
        
        let now = Date()
        suspendedAt = pumpManager.state.suspendedAt
        basalDeliveryState = pumpManager.status.basalDeliveryState
        basalDeliveryRate = pumpManager.state.basalDeliveryRate(at: now)
        basalDeliveryRateDate = now
        automatedTreatmentState = pumpManager.pumpManagerDelegate?.automatedTreatmentState ?? .neutralNoOverride
        setSuspenededAtString()
        
        pumpManager.addStateObserver(self, queue: .main)
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.significantTimeChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateDisplayOfPumpTime()
            }
        }
    }
    
    private func setSuspenededAtString() {
        switch basalDeliveryState {
        case .suspended(let suspendedAt):
            self.suspendedAt = suspendedAt
        default:
            self.suspendedAt = nil
        }
    }
    
    func resumeInsulinDelivery(completion: @escaping (Error?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            self?.transitioningSuspendResumeInsulinDelivery = true
            self?.pumpManager.resumeDelivery() { [weak self] error in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if error == nil {
                        self?.suspendedAt = nil
                    }
                    self?.transitioningSuspendResumeInsulinDelivery = false
                    completion(error)
                }
            }
        }
    }
    
    enum SuspendResumeInsulinDeliveryStatus {
        case suspended
        case suspending
        case resumed
        case resuming
        
        var localizedLabel: String {
            switch self {
            case .suspended:
                return LocalizedString("Tap to Resume Insulin Delivery", comment: "Label when the user can resume insulin delivery")
            case .suspending:
                return LocalizedString("Suspending Insulin Delivery", comment: "Label when suspending insulin delivery")
            case .resumed:
                return LocalizedString("Suspend Insulin Delivery", comment: "Label when the user can suspend insulin delivery")
            case .resuming:
                return LocalizedString("Resuming Insulin Delivery", comment: "Label when resuming insulin delivery")
            }
        }
        
        var showPauseIcon: Bool {
            self == .suspended || self == .resuming
        }
    }

    var suspendResumeInsulinDeliveryStatus: SuspendResumeInsulinDeliveryStatus {
        if isDeliverySuspended {
            if transitioningSuspendResumeInsulinDelivery {
                return .resuming
            } else {
                return .suspended
            }
        } else {
            if transitioningSuspendResumeInsulinDelivery {
                return .suspending
            } else {
                return .resumed
            }
        }
    }
    
    func suspendInsulinDelivery(reminderDelay: TimeInterval, completion: @escaping (Error?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            self?.transitioningSuspendResumeInsulinDelivery = true
            self?.pumpManager.suspendDelivery(reminderDelay: reminderDelay) { error in
                DispatchQueue.main.async {
                    if error == nil {
                        self?.suspendedAt = Date()
                    }
                    self?.transitioningSuspendResumeInsulinDelivery = false
                    completion(error)
                }
            }
        }
    }
    
    var isClockOffset: Bool {
        pumpManager.isClockOffset
    }
    
    var timeZone: TimeZone {
        pumpManager.status.timeZone
    }
    
    @Published var synchronizingTime: Bool = false
    
    @Published var detectedSystemTimeOffset: TimeInterval
    
    @Published var canSynchronizePumpTime: Bool
    
    func changeTimeZoneTapped(completion: @escaping (Error?) -> Void) {
        synchronizingTime = true
        pumpManager.setPumpTime(using: TimeZone.currentFixed) { [weak self] error in
            self?.synchronizingTime = false
            completion(error)
        }
    }
    
    private func updateDisplayOfPumpTime() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.detectedSystemTimeOffset = self.pumpManager.detectedSystemTimeOffset
            self.canSynchronizePumpTime = self.pumpManager.canSynchronizePumpTime
        }
    }
}

extension MockPumpManagerSettingsViewModel: MockPumpManagerStateObserver {
    func mockPumpManager(_ manager: MockKit.MockPumpManager, didUpdate state: MockKit.MockPumpManagerState) {
        guard !transitioningSuspendResumeInsulinDelivery else { return }
        let now = Date()
        basalDeliveryRateDate = now
        basalDeliveryRate = state.basalDeliveryRate(at: now)
        basalDeliveryState = manager.status.basalDeliveryState
        automatedTreatmentState = manager.pumpManagerDelegate?.automatedTreatmentState ?? .neutralNoOverride
        statusHighlight = manager.pumpStatusHighlight
    }
    
    func mockPumpManager(_ manager: MockKit.MockPumpManager, didUpdate status: LoopKit.PumpManagerStatus, oldStatus: LoopKit.PumpManagerStatus) {
        guard !transitioningSuspendResumeInsulinDelivery else { return }
        basalDeliveryRate = manager.state.basalDeliveryRate(at: Date())
        basalDeliveryState = status.basalDeliveryState
        statusHighlight = manager.pumpStatusHighlight
    }
}
 
extension MockPumpManagerState {
    func basalDeliveryRate(at now: Date) -> Double? {
        switch suspendState {
        case .resumed:
            if let tempBasal = unfinalizedTempBasal, !tempBasal.isFinished(at: now) {
                return tempBasal.rate
            } else {
                return basalRateSchedule?.value(at: now)
            }
        case .suspended, .none:
            return nil
        }
    }

    func basalDeliveryStartDate(at now: Date) -> Date? {
        switch suspendState {
        case .resumed:
            if let tempBasal = unfinalizedTempBasal, !tempBasal.isFinished(at: now) {
                return tempBasal.startTime
            } else {
                return basalRateSchedule?.startDate(at: now)
            }
        case .suspended, .none:
            return nil
        }
    }
}
