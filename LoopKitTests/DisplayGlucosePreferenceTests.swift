import HealthKit
import LoopKit
import LoopKitUI
import XCTest

final class DisplayGlucosePreferenceTests: XCTestCase {
    private let milligramsPerDeciliter = HKUnit.gramUnit(with: .milli)
        .unitDivided(by: .literUnit(with: .deci))
    private let millimolesPerLiter = HKUnit.moleUnit(with: .milli, molarMass: HKUnitMolarMassBloodGlucose)
        .unitDivided(by: .liter())

    func testUnitDidChangeUpdatesRateUnitsFormattersAndNaNPlaceholdersInBothDirections() {
        let enUS = Locale(identifier: "en_US")
        let preference = DisplayGlucosePreference(displayGlucoseUnit: milligramsPerDeciliter)
        configure(preference, locale: enUS)

        preference.unitDidChange(to: millimolesPerLiter)
        configure(preference, locale: enUS)

        let millimolesPerLiterPerMinute = millimolesPerLiter.unitDivided(by: .minute())
        XCTAssertEqual(preference.unit, millimolesPerLiter)
        XCTAssertEqual(preference.rateUnit, millimolesPerLiterPerMinute)
        XCTAssertEqual(
            preference.format(HKQuantity(unit: millimolesPerLiter, doubleValue: 5.5)),
            "5.5 mmol/L"
        )
        XCTAssertEqual(
            preference.formatMinuteRate(HKQuantity(unit: millimolesPerLiterPerMinute, doubleValue: 0.3)),
            "0.3 mmol/L/min"
        )
        XCTAssertEqual(preference.formatter.numberFormatter.notANumberSymbol, "–")
        XCTAssertEqual(preference.minuteRateFormatter.numberFormatter.notANumberSymbol, "–")

        preference.unitDidChange(to: milligramsPerDeciliter)
        configure(preference, locale: enUS)

        let milligramsPerDeciliterPerMinute = milligramsPerDeciliter.unitDivided(by: .minute())
        XCTAssertEqual(preference.unit, milligramsPerDeciliter)
        XCTAssertEqual(preference.rateUnit, milligramsPerDeciliterPerMinute)
        XCTAssertEqual(
            preference.format(HKQuantity(unit: milligramsPerDeciliter, doubleValue: 100)),
            "100 mg/dL"
        )
        XCTAssertEqual(
            preference.formatMinuteRate(HKQuantity(unit: milligramsPerDeciliterPerMinute, doubleValue: 1)),
            "1.0 mg/dL/min"
        )
        XCTAssertEqual(preference.formatter.numberFormatter.notANumberSymbol, "–")
        XCTAssertEqual(preference.minuteRateFormatter.numberFormatter.notANumberSymbol, "–")
    }

    private func configure(_ preference: DisplayGlucosePreference, locale: Locale) {
        preference.formatter.locale = locale
        preference.minuteRateFormatter.locale = locale
        preference.formatter.avoidLineBreaking = false
        preference.minuteRateFormatter.avoidLineBreaking = false
    }
}
