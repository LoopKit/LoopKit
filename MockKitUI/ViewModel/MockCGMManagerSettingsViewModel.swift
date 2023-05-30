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
    
    @Published private(set) var lastGlucoseDate: Date? {
        didSet {
            updateLastReadingTime()
        }
    }
    
    @Published var lastReadingMinutesFromNow: Int = 0
    
    func updateLastReadingTime() {
        guard let lastGlucoseDate = lastGlucoseDate else {
            lastReadingMinutesFromNow = 0
            return
        }
        lastReadingMinutesFromNow = Int(Date().timeIntervalSince(lastGlucoseDate).minutes)
    }
    
    @Published private(set) var lastGlucoseTrend: GlucoseTrend?
    
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
                
        lastGlucoseDate = cgmManager.cgmManagerStatus.lastCommunicationDate
        lastGlucoseTrend = cgmManager.mockSensorState.trendType
        setLastGlucoseTrend(cgmManager.mockSensorState.trendRate)
        setLastGlucoseValue(cgmManager.mockSensorState.currentGlucose)
        
        cgmManager.addStatusObserver(self, queue: .main)
    }
    
    func setLastGlucoseTrend(_ trendRate: HKQuantity?) {
        guard let trendRate = trendRate else {
            lastGlucoseTrendFormatted = nil
            return
        }
        let glucoseUnitPerMinute = displayGlucosePreference.unit.unitDivided(by: .minute())
        lastGlucoseTrendFormatted = displayGlucosePreference.formatMinuteRate(trendRate)
    }
    
    func setLastGlucoseValue(_ lastGlucose: HKQuantity?) {
        guard let lastGlucose = lastGlucose else {
            lastGlucoseValueWithUnitFormatted = nil
            lastGlucoseValueFormatted = "---"
            return
        }

        lastGlucoseValueWithUnitFormatted = displayGlucosePreference.format(lastGlucose)
        lastGlucoseValueFormatted = displayGlucosePreference.format(lastGlucose, includeUnit: false)
    }
}

extension MockCGMManagerSettingsViewModel: CGMManagerStatusObserver {
    func cgmManager(_ manager: LoopKit.CGMManager, didUpdate status: LoopKit.CGMManagerStatus) {
        lastGlucoseDate = status.lastCommunicationDate

        lastGlucoseTrend = cgmManager.mockSensorState.trendType
        
        setLastGlucoseTrend(cgmManager.mockSensorState.trendRate)
        
        setLastGlucoseValue(cgmManager.mockSensorState.currentGlucose)
    }
}
