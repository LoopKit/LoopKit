//
//  TherapyProfileUITests.swift
//  LoopKitTests
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit
@testable import LoopKitUI

final class TherapyProfileUITests: XCTestCase {

    private let timeZone = TimeZone(secondsFromGMT: 0)!
    private let increments = PumpSupportedIncrements(basalRates: (0...600).map { (Double($0) * 5).rounded() / 100 },
                                                     bolusVolumes: [1], maximumBolusVolumes: [10], maximumBasalScheduleEntryCount: 24)

    private func profile(_ name: String, basal: Double, targetLow: Double = 100) -> TherapyProfile {
        TherapyProfile(name: name,
                       glucoseTargetRangeSchedule: GlucoseRangeSchedule(unit: .milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue(startTime: 0, value: DoubleRange(minValue: targetLow, maxValue: 120))], timeZone: timeZone)!,
                       carbRatioSchedule: CarbRatioSchedule(unit: .gram, dailyItems: [RepeatingScheduleValue(startTime: 0, value: 10)], timeZone: timeZone)!,
                       basalRateSchedule: BasalRateSchedule(dailyItems: [RepeatingScheduleValue(startTime: 0, value: basal)], timeZone: timeZone)!,
                       insulinSensitivitySchedule: InsulinSensitivitySchedule(unit: .milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue(startTime: 0, value: 50)], timeZone: timeZone)!)
    }

    private final class Delegate: TherapySettingsViewModelDelegate {
        let increments: PumpSupportedIncrements?
        init(increments: PumpSupportedIncrements?) { self.increments = increments }
        func syncBasalRateSchedule(items: [RepeatingScheduleValue<Double>], completion: @escaping (Result<BasalRateSchedule, Error>) -> Void) {}
        func syncDeliveryLimits(deliveryLimits: DeliveryLimits) async throws -> DeliveryLimits { deliveryLimits }
        func saveCompletion(therapySettings: TherapySettings) {}
        func pumpSupportedIncrements() -> PumpSupportedIncrements? { increments }
    }

    private func settings(_ profiles: [TherapyProfile]) -> TherapySettings {
        TherapySettings(maximumBasalRatePerHour: 2,
                        suspendThreshold: GlucoseThreshold(unit: .milligramsPerDeciliter, value: 75),
                        therapyProfiles: profiles)
    }

    func testProfilesFailingAfterAChangeNameOnlyTheProfilesTheChangeBreaks() {
        let profiles = [profile("Default", basal: 0.5), profile("High", basal: 1.5), profile("Already", basal: 2.5), profile("LowTarget", basal: 0.5, targetLow: 90)]
        let delegate = Delegate(increments: increments)
        let viewModel = TherapySettingsViewModel(therapySettings: settings(profiles), delegate: delegate)
        XCTAssertEqual(viewModel.therapyProfilesFailing { $0.maximumBasalRatePerHour = 1.0 }, ["High"])
        XCTAssertEqual(viewModel.therapyProfilesFailing { $0.suspendThreshold = GlucoseThreshold(unit: .milligramsPerDeciliter, value: 95) }, ["LowTarget"])
        XCTAssertEqual(viewModel.therapyProfilesFailing { $0.maximumBasalRatePerHour = 3.0 }, [])
        XCTAssertEqual(TherapySettingsViewModel(therapySettings: settings(profiles), delegate: Delegate(increments: nil)).therapyProfilesFailing { $0.maximumBasalRatePerHour = 1.0 }, [])
    }

    func testFailingMessageNamesOneOrSeveralProfiles() {
        XCTAssertEqual(TherapySettingsViewModel.therapyProfilesFailingMessage(["High"]), "With this change, High can no longer be activated until its settings are edited to fit.")
        XCTAssertEqual(TherapySettingsViewModel.therapyProfilesFailingMessage(["High", "Low"]), "With this change, these profiles can no longer be activated until their settings are edited to fit: \(ListFormatter.localizedString(byJoining: ["High", "Low"])).")
    }

    @MainActor
    func testActivationProblemsDescribeEachFailingScheduleOfEachProfile() throws {
        let validator = try XCTUnwrap(TherapyProfileValidator(therapySettings: settings([]), pumpSupportedIncrements: increments))
        let problems = TherapyProfilesViewModel.activationProblems(of: [profile("Default", basal: 0.5), profile("Broken", basal: 2.5, targetLow: 80)], validator: validator)
        XCTAssertEqual(Array(problems.keys), ["Broken"])
        let lines = try XCTUnwrap(problems["Broken"]).components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].hasPrefix(TherapySetting.glucoseTargetRange.title + ": "))
        XCTAssertTrue(lines[1].hasPrefix(TherapySetting.basalRate.title + ": "))
        XCTAssertTrue(TherapyProfilesViewModel.activationProblems(of: [profile("Broken", basal: 2.5)], validator: nil).isEmpty)
        XCTAssertNil(TherapyProfileValidator(therapySettings: settings([]), pumpSupportedIncrements: nil))
    }
}
