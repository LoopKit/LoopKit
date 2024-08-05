//
//  MockCGMManagerSettingsViewModel.swift
//  MockKitUI
//
//  Created by Nathaniel Hamming on 2023-05-18.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import Combine
import HealthKit
import LoopKit
import LoopKitUI
import MockKit

class MockCGMManagerSettingsViewModel: ObservableObject {
    
    let cgmManager: MockCGMManager
    
    var displayGlucosePreference: DisplayGlucosePreference

    static private let dateTimeFormatter: DateFormatter = {
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .short
        timeFormatter.timeStyle = .short
        return timeFormatter
    }()
    
    var sensorInsertionDateTimeString: String {
        Self.dateTimeFormatter.string(from: Date().addingTimeInterval(sensorInsertionInterval))
    }

    var sensorExpirationRemaining = TimeInterval(days: 5.0)
    var sensorInsertionInterval = TimeInterval(days: -5.0)
    var sensorExpirationPercentComplete: Double = 0.25

    var sensorExpirationDateTimeString: String {
        Self.dateTimeFormatter.string(from: Date().addingTimeInterval(sensorExpirationRemaining))
    }
    
    @Published private(set) var lastGlucoseValueWithUnitFormatted: String?
    
    @Published private(set) var lastGlucoseValueFormatted: String = "---"
    
    var glucoseUnitString: String {
        displayGlucosePreference.unit.shortLocalizedUnitString()
    }

    var shouldDisplayUnitsForCurrentGlucose: Bool {
        switch cgmManager.mockSensorState.glucoseRangeCategory {
        case .aboveRange, .belowRange:
            return false
        default:
            return true
        }
    }

    @Published private(set) var lastGlucoseDate: Date? {
        didSet {
            updateLastReadingTime()
        }
    }
    
    @Published var lastReadingMinutesFromNow: Int = 0

    @Published var fobId: Int?

    func updateLastReadingTime() {
        guard let lastGlucoseDate = lastGlucoseDate else {
            lastReadingMinutesFromNow = 0
            return
        }
        lastReadingMinutesFromNow = Int(Date().timeIntervalSince(lastGlucoseDate).minutes)
    }
    
    @Published private(set) var lastGlucoseTrend: GlucoseTrend?
    

    var bleHeartbeatStatus: String? {
        if let fobId {
            return "Fob ID #\(fobId)"
        } else {
            return "Not Paired"
        }
    }

    var lastGlucoseDateFormatted: String? {
        guard let lastGlucoseDate = lastGlucoseDate else {
            return nil
        }
        return Self.dateTimeFormatter.string(from: lastGlucoseDate)
    }
    
    @Published private(set) var lastGlucoseTrendFormatted: String?
    
    init(cgmManager: MockCGMManager, displayGlucosePreference: DisplayGlucosePreference) {
        self.cgmManager = cgmManager
        self.displayGlucosePreference = displayGlucosePreference

        self.fobId = cgmManager.mockSensorState.heartbeatFobId

        lastGlucoseDate = cgmManager.cgmManagerStatus.lastCommunicationDate
        lastGlucoseTrend = cgmManager.mockSensorState.trendType
        setLastGlucoseTrend(cgmManager.mockSensorState.trendRate)
        setLastGlucoseValue()
        
        cgmManager.addStatusObserver(self, queue: .main)
    }
    
    func setLastGlucoseTrend(_ trendRate: HKQuantity?) {
        guard let trendRate = trendRate else {
            lastGlucoseTrendFormatted = nil
            return
        }
        lastGlucoseTrendFormatted = displayGlucosePreference.formatMinuteRate(trendRate)
    }
    
    func setLastGlucoseValue() {
        guard let lastGlucose = cgmManager.mockSensorState.currentGlucose else {
            lastGlucoseValueWithUnitFormatted = nil
            lastGlucoseValueFormatted = "---"
            return
        }

        switch cgmManager.mockSensorState.glucoseRangeCategory {
        case .aboveRange:
            let glucoseString = LocalizedString("HIGH", comment: "String displayed instead of a glucose value above the CGM range")
            lastGlucoseValueWithUnitFormatted = glucoseString
            lastGlucoseValueFormatted = glucoseString
        case .belowRange:
            let glucoseString = LocalizedString("LOW", comment: "String displayed instead of a glucose value below the CGM range")
            lastGlucoseValueWithUnitFormatted = glucoseString
            lastGlucoseValueFormatted = glucoseString
        default:
            lastGlucoseValueWithUnitFormatted = displayGlucosePreference.format(lastGlucose)
            lastGlucoseValueFormatted = displayGlucosePreference.format(lastGlucose, includeUnit: false)
        }

    }
}

extension MockCGMManagerSettingsViewModel: CGMManagerStatusObserver {
    func cgmManager(_ manager: LoopKit.CGMManager, didUpdate status: LoopKit.CGMManagerStatus) {
        lastGlucoseDate = status.lastCommunicationDate

        lastGlucoseTrend = cgmManager.mockSensorState.trendType
        
        setLastGlucoseTrend(cgmManager.mockSensorState.trendRate)

        fobId = cgmManager.mockSensorState.heartbeatFobId

        setLastGlucoseValue()
    }
}
