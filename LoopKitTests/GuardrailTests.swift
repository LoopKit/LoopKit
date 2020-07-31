//
//  GuardrailTests.swift
//  GuardrailTests
//
//  Created by Michael Pangburn on 7/30/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
@testable import LoopKit

class GuardrailTests: XCTestCase {
    func testMaxBasalRateGuardrail() {
        let podBasalRates = (1...600).map { Double($0) / 20 }
        let smallestSupportedBasalRate = podBasalRates.first!
        var guardrail = Guardrail.maximumBasalRate(supportedBasalRates: podBasalRates, scheduledBasalRange: 0.05...0.05)
        XCTAssertEqual(guardrail.recommendedBounds.range(withUnit: .internationalUnitsPerHour), smallestSupportedBasalRate...0.3)

        guardrail = .maximumBasalRate(supportedBasalRates: podBasalRates, scheduledBasalRange: 0.1...0.2)
        XCTAssertEqual(guardrail.recommendedBounds.range(withUnit: .internationalUnitsPerHour), smallestSupportedBasalRate...1.2)

        guardrail = .maximumBasalRate(supportedBasalRates: podBasalRates, scheduledBasalRange: 0.25...0.3.nextDown)
        XCTAssertEqual(guardrail.recommendedBounds.range(withUnit: .internationalUnitsPerHour), smallestSupportedBasalRate...1.8)

        guardrail = .maximumBasalRate(supportedBasalRates: podBasalRates, scheduledBasalRange: 0.25...0.3)
        XCTAssertEqual(guardrail.recommendedBounds.range(withUnit: .internationalUnitsPerHour), smallestSupportedBasalRate...1.8)

        guardrail = .maximumBasalRate(supportedBasalRates: podBasalRates, scheduledBasalRange: 0.25...0.3.nextUp)
        XCTAssertEqual(guardrail.recommendedBounds.range(withUnit: .internationalUnitsPerHour), smallestSupportedBasalRate...1.8)

        guardrail = .maximumBasalRate(supportedBasalRates: podBasalRates, scheduledBasalRange: 0.35...0.35)
        XCTAssertEqual(guardrail.recommendedBounds.range(withUnit: .internationalUnitsPerHour), smallestSupportedBasalRate...2.1)
    }
}

fileprivate extension ClosedRange where Bound == HKQuantity {
    func range(withUnit unit: HKUnit) -> ClosedRange<Double> {
        lowerBound.doubleValue(for: unit)...upperBound.doubleValue(for: unit)
    }
}
