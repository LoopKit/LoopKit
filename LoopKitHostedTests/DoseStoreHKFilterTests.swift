//
//  DoseStoreHKFilterTests.swift
//  LoopKitHostedTests
//
//  Created by Rick Pasetto on 6/25/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit
import XCTest
import LoopKit

class DoseStoreHKFilterTests: XCTestCase {
    let sampleFromCurrentApp: [String : Any] = [ "endDate": Date(), "source": HKSource.default() ]
    let sampleFromOutsideCurrentApp: [String : Any] = [ "endDate": Date(), "source": "other" ]

    func testEntriesFromAllSources() {
        checkEntries(observeHealthKitSamplesFromOtherApps: true)
    }
    
    func testEntriesFromCurrentAppOnly() {
        checkEntries(observeHealthKitSamplesFromOtherApps: false)
    }
    
    private func checkEntries(observeHealthKitSamplesFromOtherApps: Bool, file: StaticString = #file, line: UInt = #line) {
        let pc = PersistenceController(directoryURL: URL.init(fileURLWithPath: ""))
        let mockHKStore = HKHealthStoreMock()
        let doseStore = DoseStore(healthStore: mockHKStore, observeHealthKitSamplesFromOtherApps: observeHealthKitSamplesFromOtherApps, cacheStore: pc, insulinModel: nil, basalProfile: nil, insulinSensitivitySchedule: nil)
        doseStore.getNormalizedDoseEntries(start: Date.distantPast.addingTimeInterval(1.0)) { _ in }
        guard let predicate = try? XCTUnwrap(mockHKStore.lastQuery?.predicate, file: file, line: line) else { return }
        XCTAssertTrue(predicate.evaluate(with: sampleFromCurrentApp), file: file, line: line)
        XCTAssertEqual(observeHealthKitSamplesFromOtherApps, predicate.evaluate(with: sampleFromOutsideCurrentApp), file: file, line: line)
    }
}
