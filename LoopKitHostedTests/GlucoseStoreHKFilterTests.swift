//
//  GlucoseStoreHKFilterTests.swift
//  LoopKitHostedTests
//
//  Created by Rick Pasetto on 6/25/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit
import XCTest
import LoopKit

class GlucoseStoreHKFilterTests: XCTestCase {
    let sampleFromCurrentApp: [String : Any] = [ "endDate": Date(), "source": HKSource.default() ]
    let sampleFromOutsideCurrentApp: [String : Any] = [ "endDate": Date(), "source": "other" ]

    func testEntriesFromAllSources() {
        checkEntries(fromCurrentAppOnly: false)
    }
    
    func testEntriesFromCurrentAppOnly() {
        checkEntries(fromCurrentAppOnly: true)
    }
    
    private func checkEntries(fromCurrentAppOnly: Bool, file: StaticString = #file, line: UInt = #line) {
        let pc = PersistenceController(directoryURL: URL.init(fileURLWithPath: ""))
        let mockHKStore = HKHealthStoreMock()
        let glucoseStore = GlucoseStore(healthStore: mockHKStore, observeHealthKitForCurrentAppOnly: fromCurrentAppOnly, cacheStore: pc)
        glucoseStore.getGlucoseSamples(start: Date.distantPast) { _ in }
        guard let predicate = try? XCTUnwrap(mockHKStore.lastQuery?.predicate, file: file, line: line) else { return }
        XCTAssertTrue(predicate.evaluate(with: sampleFromCurrentApp), file: file, line: line)
        XCTAssertEqual(!fromCurrentAppOnly, predicate.evaluate(with: sampleFromOutsideCurrentApp), file: file, line: line)
    }
    
}
