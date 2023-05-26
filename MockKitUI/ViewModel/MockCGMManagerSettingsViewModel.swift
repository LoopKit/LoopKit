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
    
    var displayGlucoseUnitObservable: DisplayGlucoseUnitObservable

    static private let dateTimeFormatter: DateFormatter = {
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .short
        timeFormatter.timeStyle = .short
        return timeFormatter
    }()
    
    private lazy var glucoseFormatter: QuantityFormatter = {
        let formatter = QuantityFormatter()
        formatter.setPreferredNumberFormatter(for: displayGlucoseUnitObservable.displayGlucoseUnit)
        formatter.numberFormatter.notANumberSymbol = "–"
        formatter.avoidLineBreaking = true
        return formatter
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
        displayGlucoseUnitObservable.displayGlucoseUnit.shortLocalizedUnitString()
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
    
    lazy private var cancellables = Set<AnyCancellable>()
    
    init(cgmManager: MockCGMManager, displayGlucoseUnitObservable: DisplayGlucoseUnitObservable) {
        self.cgmManager = cgmManager
        self.displayGlucoseUnitObservable = displayGlucoseUnitObservable
                
        lastGlucoseDate = cgmManager.cgmManagerStatus.lastCommunicationDate
        lastGlucoseTrend = cgmManager.mockSensorState.trendType
        setLastGlucoseTrend(cgmManager.mockSensorState.trendRate)
        setLastGlucoseValue(cgmManager.mockSensorState.currentGlucose)
        
        cgmManager.addStatusObserver(self, queue: .main)
        
        self.displayGlucoseUnitObservable.$displayGlucoseUnit
            .sink { [weak self] in self?.glucoseFormatter.setPreferredNumberFormatter(for: $0) }
            .store(in: &cancellables)
    }
    
    func setLastGlucoseTrend(_ trendRate: HKQuantity?) {
        guard let trendRate = trendRate else {
            lastGlucoseTrendFormatted = nil
            return
        }
        let glucoseUnitPerMinute = displayGlucoseUnitObservable.displayGlucoseUnit.unitDivided(by: .minute())
        // This seemingly strange replacement of glucose units is only to display the unit string correctly
        let trendPerMinute = HKQuantity(unit: displayGlucoseUnitObservable.displayGlucoseUnit, doubleValue: trendRate.doubleValue(for: glucoseUnitPerMinute))
        if let formatted = glucoseFormatter.string(from: trendPerMinute, for: displayGlucoseUnitObservable.displayGlucoseUnit) {
            lastGlucoseTrendFormatted = String(format: LocalizedString("%@/min", comment: "Format string for glucose trend per minute. (1: glucose value and unit)"), formatted)
        }
    }
    
    func setLastGlucoseValue(_ lastGlucose: HKQuantity?) {
        guard let lastGlucose = lastGlucose else {
            lastGlucoseValueWithUnitFormatted = nil
            lastGlucoseValueFormatted = "---"
            return
        }

        lastGlucoseValueWithUnitFormatted = glucoseFormatter.string(from: lastGlucose, for: displayGlucoseUnitObservable.displayGlucoseUnit)
        lastGlucoseValueFormatted = glucoseFormatter.string(from: lastGlucose, for: displayGlucoseUnitObservable.displayGlucoseUnit, includeUnit: false) ?? "---"
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
