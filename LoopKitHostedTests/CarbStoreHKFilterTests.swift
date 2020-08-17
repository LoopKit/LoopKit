//
//  CarbStoreHKFilterTests.swift
//  LoopKitHostedTests
//
//  Created by Rick Pasetto on 6/25/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit
import XCTest
import LoopKit

class CarbStoreHKFilterTests: XCTestCase {
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
        let carbStore = CarbStore(
            healthStore: mockHKStore,
            observeHealthKitSamplesFromOtherApps: observeHealthKitSamplesFromOtherApps,
            cacheStore: pc,
            cacheLength: .hours(24),
            defaultAbsorptionTimes: (fast: .minutes(30), medium: .hours(3), slow: .hours(5)),
            observationInterval: .hours(24)
        )
        carbStore.getCarbEntries(start: Date.distantPast) { _ in }
        guard let predicate = try? XCTUnwrap(mockHKStore.lastQuery?.predicate, file: file, line: line) else { return }
        XCTAssertTrue(predicate.evaluate(with: sampleFromCurrentApp), file: file, line: line)
        XCTAssertEqual(observeHealthKitSamplesFromOtherApps, predicate.evaluate(with: sampleFromOutsideCurrentApp), file: file, line: line)
    }

}
