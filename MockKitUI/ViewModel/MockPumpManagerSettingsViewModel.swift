//
//  MockPumpManagerSettingsViewModel.swift
//  MockKitUI
//
//  Created by Nathaniel Hamming on 2023-05-18.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import MockKit

class MockPumpManagerSettingsViewModel: ObservableObject {
    let pumpManager: MockPumpManager
    
    @Published private(set) var isDeliverySuspended: Bool {
        didSet {
            transitioningSuspendResumeInsulinDelivery = false
            basalDeliveryState = pumpManager.status.basalDeliveryState
        }
    }
    
    @Published private(set) var transitioningSuspendResumeInsulinDelivery = false
    
    @Published private(set) var suspendedAtString: String? = nil
    
    var suspendResumeInsulinDeliveryLabel: String {
        if isDeliverySuspended {
            return "Tap to Resume Insulin Delivery"
        } else {
            return "Suspend Insulin Delivery"
        }
    }
    
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
    
    var pumpTimeString: String {
        Self.shortTimeFormatter.string(from: Date())
    }
    
    @Published private(set) var basalDeliveryState: PumpManagerStatus.BasalDeliveryState? {
        didSet {
            setSuspenededAtString()
        }
    }

    @Published private(set) var basalDeliveryRate: Double?

    @Published private(set) var presentDeliveryWarning: Bool?
    
    var isScheduledBasal: Bool {
        switch basalDeliveryState {
        case .active, .initiatingTempBasal:
            return true
        case .tempBasal, .cancelingTempBasal, .suspending, .suspended, .resuming, .none:
            return false
        }
    }
    
    var isTempBasal: Bool {
        switch basalDeliveryState {
        case .tempBasal, .cancelingTempBasal:
            return true
        case .active, .initiatingTempBasal, .suspending, .suspended, .resuming, .none:
            return false
        }
    }
    
    init(pumpManager: MockPumpManager) {
        self.pumpManager = pumpManager
        
        isDeliverySuspended = pumpManager.status.basalDeliveryState?.isSuspended == true
        basalDeliveryState = pumpManager.status.basalDeliveryState
        basalDeliveryRate = pumpManager.state.basalDeliveryRate(at: Date())
        setSuspenededAtString()
        
        pumpManager.addStateObserver(self, queue: .main)
    }
    
    private func setSuspenededAtString() {
        switch basalDeliveryState {
        case .suspended(let suspendedAt):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            formatter.doesRelativeDateFormatting = true
            suspendedAtString = formatter.string(from: suspendedAt)
        default:
            suspendedAtString = nil
        }
    }
    
    func resumeDelivery(completion: @escaping (Error?) -> Void) {
        transitioningSuspendResumeInsulinDelivery = true
        pumpManager.resumeDelivery() { [weak self] error in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if error == nil {
                    self?.isDeliverySuspended = false
                }
                completion(error)
            }
        }
    }
    
    func suspendDelivery(completion: @escaping (Error?) -> Void) {
        transitioningSuspendResumeInsulinDelivery = true
        pumpManager.suspendDelivery() { [weak self] error in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if error == nil {
                    self?.isDeliverySuspended = true
                }
                completion(error)
            }
        }
    }
}

extension MockPumpManagerSettingsViewModel: MockPumpManagerStateObserver {
    func mockPumpManager(_ manager: MockKit.MockPumpManager, didUpdate state: MockKit.MockPumpManagerState) {
        guard !transitioningSuspendResumeInsulinDelivery else { return }
        basalDeliveryRate = state.basalDeliveryRate(at: Date())
        basalDeliveryState = manager.status.basalDeliveryState
    }
    
    func mockPumpManager(_ manager: MockKit.MockPumpManager, didUpdate status: LoopKit.PumpManagerStatus, oldStatus: LoopKit.PumpManagerStatus) {
        guard !transitioningSuspendResumeInsulinDelivery else { return }
        basalDeliveryRate = manager.state.basalDeliveryRate(at: Date())
        basalDeliveryState = status.basalDeliveryState
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
        case .suspended:
            return nil
        }
    }
}
