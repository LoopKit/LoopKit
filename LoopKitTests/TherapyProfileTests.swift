//
//  TherapyProfileTests.swift
//  LoopKitTests
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit

final class TherapyProfileTests: XCTestCase {

    private let timeZone = TimeZone(secondsFromGMT: 3600)!
    private let supportedBasalRates = (0...600).map { (Double($0) * 5).rounded() / 100 }

    private func profile(_ name: String,
                         target: [(TimeInterval, Double, Double)] = [(0, 100, 110)],
                         carbRatio: [(TimeInterval, Double)] = [(0, 10)],
                         basal: [(TimeInterval, Double)] = [(0, 0.85), (.hours(6), 1.0)],
                         sensitivity: [(TimeInterval, Double)] = [(0, 50)],
                         unit: LoopUnit = .milligramsPerDeciliter) -> TherapyProfile {
        TherapyProfile(name: name,
                       glucoseTargetRangeSchedule: GlucoseRangeSchedule(unit: unit, dailyItems: target.map { RepeatingScheduleValue(startTime: $0.0, value: DoubleRange(minValue: $0.1, maxValue: $0.2)) }, timeZone: timeZone)!,
                       carbRatioSchedule: CarbRatioSchedule(unit: .gram, dailyItems: carbRatio.map { RepeatingScheduleValue(startTime: $0.0, value: $0.1) }, timeZone: timeZone)!,
                       basalRateSchedule: BasalRateSchedule(dailyItems: basal.map { RepeatingScheduleValue(startTime: $0.0, value: $0.1) }, timeZone: timeZone)!,
                       insulinSensitivitySchedule: InsulinSensitivitySchedule(unit: unit, dailyItems: sensitivity.map { RepeatingScheduleValue(startTime: $0.0, value: $0.1) }, timeZone: timeZone)!)
    }

    private var validator: TherapyProfileValidator {
        TherapyProfileValidator(supportedBasalRates: supportedBasalRates,
                                maximumBasalRatePerHour: 3.0,
                                maximumBasalScheduleEntryCount: 24,
                                suspendThreshold: GlucoseThreshold(unit: .milligramsPerDeciliter, value: 75))
    }

    private func assertRejects(_ profile: TherapyProfile, file: StaticString = #filePath, line: UInt = #line, _ check: (TherapyProfileError) -> Bool) {
        XCTAssertThrowsError(try validator.validate(profile), file: file, line: line) { error in
            guard let error = error as? TherapyProfileError, check(error) else {
                return XCTFail("Unexpected error \(error)", file: file, line: line)
            }
        }
    }

    func testMillimolarValuesAreValidExactlyWithinTheGuardrailPickers() throws {
        let unit = LoopUnit.millimolesPerLiter
        func accepts(target: (Double, Double), sensitivity: Double) -> Bool {
            (try? validator.validate(profile("Edge", target: [(0, target.0, target.1)], sensitivity: [(0, sensitivity)], unit: unit))) != nil
        }
        XCTAssertEqual(Guardrail.correctionRange.allValues(forUnit: unit).first, 4.8)
        XCTAssertEqual(Guardrail.correctionRange.allValues(forUnit: unit).last, 10.0)
        XCTAssertEqual(Guardrail.insulinSensitivity.allValues(forUnit: .millimolesPerLiterPerInternationalUnit).last, 27.8)
        XCTAssertTrue(accepts(target: (4.8, 10.0), sensitivity: 27.8))
        XCTAssertTrue(accepts(target: (5.6, 6.1), sensitivity: 0.6))
        XCTAssertFalse(accepts(target: (4.7, 6.1), sensitivity: 2.8))
        XCTAssertFalse(accepts(target: (5.6, 10.1), sensitivity: 2.8))
        XCTAssertFalse(accepts(target: (5.6, 6.1), sensitivity: 27.9))
        XCTAssertFalse(accepts(target: (5.6, 6.1), sensitivity: 0.5))
        // mg/dL keeps the guardrail bounds.
        XCTAssertNoThrow(try validator.validate(profile("Edge", target: [(0, 87, 180)], sensitivity: [(0, 500)])))
        XCTAssertThrowsError(try validator.validate(profile("Edge", target: [(0, 86, 180)])))
        XCTAssertThrowsError(try validator.validate(profile("Edge", sensitivity: [(0, 501)])))
    }

    // MARK: StoredSettings

    func testStoredSettingsWithoutProfileKeysDecodes() throws {
        let original = StoredSettings(date: Date(timeIntervalSince1970: 1_700_000_000),
                                      glucoseTargetRangeSchedule: profile("x").glucoseTargetRangeSchedule,
                                      basalRateSchedule: profile("x").basalRateSchedule,
                                      bloodGlucoseUnit: .milligramsPerDeciliter,
                                      syncIdentifier: UUID())
        let data = try PropertyListEncoder().encode(original)
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertNil(plist["therapyProfiles"])
        XCTAssertNil(plist["activeProfileName"])

        let decoded = try PropertyListDecoder().decode(StoredSettings.self, from: data)
        XCTAssertEqual(decoded.therapyProfiles, [])
        XCTAssertNil(decoded.activeProfileName)
        XCTAssertEqual(decoded, original)
    }

    func testStoredSettingsWithProfilesRoundTrips() throws {
        let live = profile("Sport", basal: [(0, 0.5)])
        let original = StoredSettings(glucoseTargetRangeSchedule: live.glucoseTargetRangeSchedule,
                                      basalRateSchedule: live.basalRateSchedule,
                                      insulinSensitivitySchedule: live.insulinSensitivitySchedule,
                                      carbRatioSchedule: live.carbRatioSchedule,
                                      bloodGlucoseUnit: .milligramsPerDeciliter,
                                      therapyProfiles: [profile(TherapyProfile.defaultName), live],
                                      activeProfileName: "Sport")
        let decoded = try PropertyListDecoder().decode(StoredSettings.self, from: PropertyListEncoder().encode(original))
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.resolvedTherapyProfiles.map(\.name), ["Default", "Sport"])
        XCTAssertEqual(decoded.liveTherapyProfile?.name, "Sport")
    }

    func testStoredSettingsWithProfilesReadAsTheActiveProfileWithoutTheProfileKeys() throws {
        let sport = profile("Sport", basal: [(0, 0.5)])
        var withProfiles = StoredSettings(date: Date(timeIntervalSince1970: 1_700_000_000),
                                          glucoseTargetRangeSchedule: sport.glucoseTargetRangeSchedule,
                                          basalRateSchedule: sport.basalRateSchedule,
                                          insulinSensitivitySchedule: sport.insulinSensitivitySchedule,
                                          carbRatioSchedule: sport.carbRatioSchedule,
                                          bloodGlucoseUnit: .milligramsPerDeciliter,
                                          therapyProfiles: [profile(TherapyProfile.defaultName), sport],
                                          activeProfileName: "Sport",
                                          syncIdentifier: UUID())
        var plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: PropertyListEncoder().encode(withProfiles), format: nil) as? [String: Any])
        XCTAssertNotNil(plist.removeValue(forKey: "therapyProfiles"))
        XCTAssertEqual(plist.removeValue(forKey: "activeProfileName") as? String, "Sport")

        withProfiles.therapyProfiles = []
        withProfiles.activeProfileName = nil
        let withoutProfiles = try XCTUnwrap(PropertyListSerialization.propertyList(from: PropertyListEncoder().encode(withProfiles), format: nil) as? [String: Any])
        XCTAssertEqual(plist as NSDictionary, withoutProfiles as NSDictionary)
    }

    func testStoredSettingsSkipsAnUnreadableProfile() throws {
        let sport = profile("Sport", basal: [(0, 0.5)])
        let settings = StoredSettings(date: Date(timeIntervalSince1970: 1_700_000_000),
                                      glucoseTargetRangeSchedule: sport.glucoseTargetRangeSchedule,
                                      basalRateSchedule: sport.basalRateSchedule,
                                      insulinSensitivitySchedule: sport.insulinSensitivitySchedule,
                                      carbRatioSchedule: sport.carbRatioSchedule,
                                      bloodGlucoseUnit: .milligramsPerDeciliter,
                                      therapyProfiles: [profile(TherapyProfile.defaultName), sport],
                                      activeProfileName: "Sport")
        var plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: PropertyListEncoder().encode(settings), format: nil) as? [String: Any])
        var profiles = try XCTUnwrap(plist["therapyProfiles"] as? [[String: Any]])
        profiles[0]["basalRateSchedule"] = "unreadable"
        plist["therapyProfiles"] = profiles
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)

        let decoded = try PropertyListDecoder().decode(StoredSettings.self, from: data)
        XCTAssertEqual(decoded.therapyProfiles.map(\.name), ["Sport"])
        XCTAssertEqual(decoded.activeProfileName, "Sport")
        XCTAssertEqual(decoded.basalRateSchedule, sport.basalRateSchedule)
    }

    func testResolvedProfilesBeforeAnyProfileIsDefaultFromLiveSettings() {
        let live = profile("x")
        let settings = StoredSettings(glucoseTargetRangeSchedule: live.glucoseTargetRangeSchedule,
                                      basalRateSchedule: live.basalRateSchedule,
                                      insulinSensitivitySchedule: live.insulinSensitivitySchedule,
                                      carbRatioSchedule: live.carbRatioSchedule)
        XCTAssertEqual(settings.resolvedTherapyProfiles.map(\.name), [TherapyProfile.defaultName])
        XCTAssertTrue(settings.resolvedTherapyProfiles[0].hasSameValues(as: live))
    }

    func testSynchronizingWritesLiveSchedulesToActiveProfileOnly() {
        let stored = [profile(TherapyProfile.defaultName), profile("Sport", basal: [(0, 0.5)]), profile("Ill", basal: [(0, 1.5)])]
        let live = profile("Sport", basal: [(0, 0.6)])
        let synchronized = TherapyProfiles.synchronizingActive(stored, activeProfileName: "Sport", live: live)
        XCTAssertEqual(synchronized.map(\.name), ["Default", "Sport", "Ill"])
        XCTAssertEqual(synchronized[1].basalRateSchedule.items.map(\.value), [0.6])
        XCTAssertEqual(synchronized[0], stored[0])
        XCTAssertEqual(synchronized[2], stored[2])
    }

    // MARK: Validation

    func testValidProfilePasses() throws {
        let validated = try validator.validate(profile("Sport"))
        XCTAssertEqual(validated.basalRateSchedule.items.map(\.value), [0.85, 1.0])
    }

    func testValidMillimolarProfilePasses() throws {
        XCTAssertNoThrow(try validator.validate(profile("Sport", target: [(0, 5.5, 6.1)], sensitivity: [(0, 2.8)], unit: .millimolesPerLiter)))
    }

    func testRejectsCorrectionRangeOutsideGuardrail() {
        assertRejects(profile("x", target: [(0, 100, 200)])) { if case .valueOutOfRange = $0 { return true } else { return false } }
        assertRejects(profile("x", target: [(0, 80, 100)])) { if case .valueOutOfRange = $0 { return true } else { return false } }
    }

    func testRejectsCorrectionRangeBelowSuspendThreshold() {
        let validator = TherapyProfileValidator(supportedBasalRates: supportedBasalRates, maximumBasalRatePerHour: 3, maximumBasalScheduleEntryCount: nil, suspendThreshold: GlucoseThreshold(unit: .milligramsPerDeciliter, value: 95))
        XCTAssertThrowsError(try validator.validate(profile("x", target: [(0, 90, 110)]))) { error in
            XCTAssertEqual(error as? TherapyProfileError, .correctionRangeBelowSuspendThreshold)
        }
    }

    func testRejectsTargetLowAboveHigh() {
        assertRejects(profile("x", target: [(0, 120, 110)])) { if case .invalidSchedule = $0 { return true } else { return false } }
    }

    func testRejectsCarbRatioAndSensitivityOutsideGuardrails() {
        assertRejects(profile("x", carbRatio: [(0, 1)])) { if case .valueOutOfRange = $0 { return true } else { return false } }
        assertRejects(profile("x", carbRatio: [(0, 151)])) { if case .valueOutOfRange = $0 { return true } else { return false } }
        assertRejects(profile("x", sensitivity: [(0, 9)])) { if case .valueOutOfRange = $0 { return true } else { return false } }
        assertRejects(profile("x", sensitivity: [(0, 501)])) { if case .valueOutOfRange = $0 { return true } else { return false } }
    }

    func testRejectsBasalRateNotSupportedByPump() {
        assertRejects(profile("x", basal: [(0, 0.87)])) { $0 == .unsupportedBasalRate(0.87) }
    }

    func testRejectsBasalRateAboveMaximumBasalRate() {
        assertRejects(profile("x", basal: [(0, 3.05)])) { $0 == .basalRateAboveMaximum(3.05) }
    }

    func testRejectsWithoutPumpOrMaximumBasalRate() {
        let noPump = TherapyProfileValidator(supportedBasalRates: [], maximumBasalRatePerHour: 3, maximumBasalScheduleEntryCount: nil, suspendThreshold: nil)
        XCTAssertThrowsError(try noPump.validate(profile("x"))) { XCTAssertEqual($0 as? TherapyProfileError, .noPump) }
        let noMaximum = TherapyProfileValidator(supportedBasalRates: supportedBasalRates, maximumBasalRatePerHour: nil, maximumBasalScheduleEntryCount: nil, suspendThreshold: nil)
        XCTAssertThrowsError(try noMaximum.validate(profile("x"))) { XCTAssertEqual($0 as? TherapyProfileError, .maximumBasalRateNotSet) }
    }

    func testRejectsMoreBasalEntriesThanPumpSupports() {
        let basal = (0..<25).map { (TimeInterval($0) * .minutes(30), 1.0) }
        assertRejects(profile("x", basal: basal)) { if case .invalidSchedule = $0 { return true } else { return false } }
    }

    func testRejectsMalformedSchedules() {
        func shape(_ starts: [TimeInterval]) -> Bool {
            (try? TherapyProfileValidator.validateScheduleShape(startTimes: starts, settingName: "basal")) != nil
        }
        XCTAssertTrue(shape([0, 1800, 84600]))
        XCTAssertFalse(shape([]))
        XCTAssertFalse(shape([1800, 3600]))
        XCTAssertFalse(shape([0, 3600, 1800]))
        XCTAssertFalse(shape([0, 3600, 3600]))
        XCTAssertFalse(shape([0, 900]))
        XCTAssertFalse(shape([0, 86400]))
        XCTAssertFalse(shape((0..<49).map { TimeInterval($0) * 1800 }))
        // A schedule built from out-of-order items is sorted, so the profile itself still has to start at midnight.
        assertRejects(profile("x", carbRatio: [(1800, 10)])) { if case .invalidSchedule = $0 { return true } else { return false } }
    }

    func testRejectsBadNames() {
        func error(_ name: String, existing: [String] = ["Default", "Sport"]) -> TherapyProfileError? {
            do {
                try TherapyProfileValidator.validateName(name, isDefault: false, existingNames: existing)
                return nil
            } catch {
                return error as? TherapyProfileError
            }
        }
        XCTAssertNil(error("Weekend"))
        XCTAssertEqual(error(""), .emptyName)
        XCTAssertEqual(error(" Weekend"), .untrimmedName)
        XCTAssertEqual(error(String(repeating: "a", count: 33)), .nameTooLong)
        XCTAssertNil(error(String(repeating: "a", count: 32)))
        XCTAssertEqual(error("A.B"), .invalidNameCharacter("."))
        XCTAssertEqual(error("$where"), .invalidNameCharacter("$"))
        XCTAssertEqual(error("default", existing: []), .reservedName)
        XCTAssertEqual(error("sport"), .duplicateName("sport"))
        XCTAssertNil(error("Sick day 🤒"))
        XCTAssertNil(error("Two  words"))
        XCTAssertNil(error(String(repeating: "👨‍👩‍👧‍👦", count: 32)))
        XCTAssertEqual(error(String(repeating: "👨‍👩‍👧‍👦", count: 33)), .nameTooLong)
        XCTAssertEqual(error("DEFAULT", existing: []), .reservedName)
        XCTAssertEqual(error("Cafe\u{301}", existing: ["Caf\u{E9}"]), .duplicateName("Cafe\u{301}"))
    }

    func testProfileLimitWithUnicodeNamesRoundTrip() throws {
        let fullDay = (0..<48).map { (TimeInterval($0) * .minutes(30), 0.05 * Double($0 + 1)) }
        let names = (1..<TherapyProfileValidator.maximumProfileCount).map { "Profil \($0) åäö 🏃" }
        var profiles = [profile(TherapyProfile.defaultName)]
        for name in names {
            profiles = try TherapyProfiles.saving(profile(name, basal: fullDay), originalName: nil, in: profiles, activeProfileName: nil, live: nil).profiles
        }
        XCTAssertThrowsError(try TherapyProfiles.saving(profile("One more"), originalName: nil, in: profiles, activeProfileName: nil, live: nil)) { error in
            XCTAssertEqual(error as? TherapyProfileError, .tooManyProfiles)
        }
        var renamed = profiles[1]
        renamed.name = "Renamed"
        XCTAssertNoThrow(try TherapyProfiles.saving(renamed, originalName: profiles[1].name, in: profiles, activeProfileName: nil, live: nil))
        let live = profiles[15]
        let original = StoredSettings(glucoseTargetRangeSchedule: live.glucoseTargetRangeSchedule,
                                      basalRateSchedule: live.basalRateSchedule,
                                      insulinSensitivitySchedule: live.insulinSensitivitySchedule,
                                      carbRatioSchedule: live.carbRatioSchedule,
                                      bloodGlucoseUnit: .milligramsPerDeciliter,
                                      therapyProfiles: profiles,
                                      activeProfileName: live.name)
        let decoded = try PropertyListDecoder().decode(StoredSettings.self, from: PropertyListEncoder().encode(original))
        XCTAssertEqual(decoded.resolvedTherapyProfiles.map(\.name), [TherapyProfile.defaultName] + names)
        XCTAssertEqual(decoded.liveTherapyProfile?.name, live.name)
        XCTAssertEqual(decoded.therapyProfiles.last?.basalRateSchedule.items.count, 48)
    }

    // MARK: Save and delete

    private var stored: [TherapyProfile] {
        [profile(TherapyProfile.defaultName), profile("Sport", basal: [(0, 0.5)])]
    }

    func testSaveCreatesProfile() throws {
        let result = try TherapyProfiles.saving(profile("Ill", basal: [(0, 1.5)]), originalName: nil, in: stored, activeProfileName: nil, live: nil)
        XCTAssertEqual(result.profiles.map(\.name), ["Default", "Sport", "Ill"])
        XCTAssertNil(result.activeProfileName)
    }

    func testSaveCreatesDefaultFromLiveSettingsForFirstProfile() throws {
        let live = profile("Default", basal: [(0, 0.9)])
        let result = try TherapyProfiles.saving(profile("Sport"), originalName: nil, in: [], activeProfileName: nil, live: live)
        XCTAssertEqual(result.profiles.map(\.name), ["Default", "Sport"])
        XCTAssertEqual(result.profiles[0].basalRateSchedule.items.map(\.value), [0.9])
    }

    func testSaveCreateRefusesExistingName() {
        XCTAssertThrowsError(try TherapyProfiles.saving(profile("SPORT"), originalName: nil, in: stored, activeProfileName: nil, live: nil)) {
            XCTAssertEqual($0 as? TherapyProfileError, .duplicateName("SPORT"))
        }
        XCTAssertThrowsError(try TherapyProfiles.saving(profile("Default"), originalName: nil, in: stored, activeProfileName: nil, live: nil)) {
            XCTAssertEqual($0 as? TherapyProfileError, .reservedName)
        }
    }

    func testSaveUpdatesProfile() throws {
        let result = try TherapyProfiles.saving(profile("Sport", basal: [(0, 0.4)]), originalName: "Sport", in: stored, activeProfileName: nil, live: nil)
        XCTAssertEqual(result.profiles[1].basalRateSchedule.items.map(\.value), [0.4])
        XCTAssertEqual(result.profiles[0], stored[0])
    }

    func testSaveUpdateOfMissingProfileFails() {
        XCTAssertThrowsError(try TherapyProfiles.saving(profile("Ill"), originalName: "Ill", in: stored, activeProfileName: nil, live: nil)) {
            XCTAssertEqual($0 as? TherapyProfileError, .notFound("Ill"))
        }
    }

    func testRenameKeepsPlaceAndActiveName() throws {
        let result = try TherapyProfiles.saving(profile("Running", basal: [(0, 0.5)]), originalName: "Sport", in: stored, activeProfileName: "Sport", live: nil)
        XCTAssertEqual(result.profiles.map(\.name), ["Default", "Running"])
        XCTAssertEqual(result.activeProfileName, "Running")
    }

    func testRenameConflicts() {
        let three = stored + [profile("Ill")]
        XCTAssertThrowsError(try TherapyProfiles.saving(profile("ill"), originalName: "Sport", in: three, activeProfileName: nil, live: nil)) {
            XCTAssertEqual($0 as? TherapyProfileError, .duplicateName("ill"))
        }
        XCTAssertThrowsError(try TherapyProfiles.saving(profile("Base"), originalName: "Default", in: three, activeProfileName: nil, live: nil)) {
            XCTAssertEqual($0 as? TherapyProfileError, .cannotRenameDefault)
        }
    }

    func testDeleteRefusesActiveAndDefault() throws {
        XCTAssertThrowsError(try TherapyProfiles.deleting("Default", in: stored, activeProfileName: "Sport", live: nil)) {
            XCTAssertEqual($0 as? TherapyProfileError, .cannotDeleteDefault)
        }
        XCTAssertThrowsError(try TherapyProfiles.deleting("Sport", in: stored, activeProfileName: "Sport", live: nil)) {
            XCTAssertEqual($0 as? TherapyProfileError, .cannotDeleteActive)
        }
        XCTAssertThrowsError(try TherapyProfiles.deleting("Ill", in: stored, activeProfileName: nil, live: nil)) {
            XCTAssertEqual($0 as? TherapyProfileError, .notFound("Ill"))
        }
        XCTAssertEqual(try TherapyProfiles.deleting("Sport", in: stored, activeProfileName: nil, live: nil).map(\.name), ["Default"])
    }

    func testReorderKeepsDefaultFirst() {
        let three = stored + [profile("Ill")]
        XCTAssertEqual(TherapyProfiles.reordering(three, names: ["Ill", "Default", "Sport"], live: nil, activeProfileName: nil).map(\.name), ["Default", "Ill", "Sport"])
    }

    // MARK: Fingerprint

    func testFingerprintMatchesSharedTestVector() throws {
        let profile = profile("Default")
        XCTAssertEqual(profile.canonicalFingerprintString(unit: .milligramsPerDeciliter), "basal=0:0.850,21600:1.000;carbratio=0:10.000;sens=0:50.000;target_low=0:100.000;target_high=0:110.000")
        XCTAssertEqual(profile.fingerprint(unit: .milligramsPerDeciliter), "3e603478d512da04")
    }

    func testProfileMatchesFingerprintInBothGlucoseUnits() throws {
        let sport = profile("Sport")
        let millimolar = try XCTUnwrap(sport.fingerprint(unit: .millimolesPerLiter))
        XCTAssertNotEqual(millimolar, "3e603478d512da04")
        XCTAssertTrue(sport.matches(fingerprint: "3e603478d512da04"))
        XCTAssertTrue(sport.matches(fingerprint: millimolar))
        XCTAssertFalse(profile("Sport", basal: [(0, 0.9)]).matches(fingerprint: "3e603478d512da04"))
    }

    func testStoredSettingsCarryThePumpLimitsProfilesAreCheckedAgainst() throws {
        var settings = StoredSettings(maximumBasalRatePerHour: 3.0,
                                      suspendThreshold: GlucoseThreshold(unit: .milligramsPerDeciliter, value: 75),
                                      bloodGlucoseUnit: .milligramsPerDeciliter,
                                      pumpSupportedBasalRates: supportedBasalRates,
                                      pumpMaximumBasalScheduleEntryCount: 24)
        let decoded = try PropertyListDecoder().decode(StoredSettings.self, from: PropertyListEncoder().encode(settings))
        XCTAssertEqual(decoded, settings)
        let validator = try XCTUnwrap(decoded.therapyProfileValidator)
        XCTAssertEqual(validator.editLimits(unit: .milligramsPerDeciliter), self.validator.editLimits(unit: .milligramsPerDeciliter))

        settings.pumpSupportedBasalRates = nil
        XCTAssertNil(settings.therapyProfileValidator)
    }

    // MARK: Edit limits

    func testEditLimitsInMilligramsPerDeciliter() throws {
        let limits = try XCTUnwrap(validator.editLimits(unit: .milligramsPerDeciliter))
        XCTAssertEqual(limits.maximumBasalRatePerHour, 3.0)
        XCTAssertEqual(limits.basalRates.first, 0)
        XCTAssertEqual(limits.basalRates.last, 3.0)
        XCTAssertEqual(limits.target.bounds, 87...180)
        XCTAssertEqual(limits.carbRatio.bounds, 2...150)
        XCTAssertEqual(limits.carbRatio.recommended, 4...28)
        XCTAssertEqual(limits.sensitivity.bounds, 10...500)
        XCTAssertEqual(limits.sensitivity.recommended, 16...399)
        XCTAssertEqual(limits.maximumScheduleEntryCount, 48)
        XCTAssertEqual(limits.segmentInterval, 1800)
    }

    func testEditLimitsInMillimolesPerLiterMatchTheGuardrailPickers() throws {
        let limits = try XCTUnwrap(validator.editLimits(unit: .millimolesPerLiter))
        XCTAssertEqual(limits.target.step, 0.1)
        XCTAssertEqual(limits.target.bounds.lowerBound, 4.8, accuracy: 0.0001)
        XCTAssertEqual(limits.target.bounds.upperBound, 10.0, accuracy: 0.0001)
        XCTAssertEqual(limits.sensitivity.bounds.upperBound, 27.8, accuracy: 0.0001)
        XCTAssertNoThrow(try validator.validate(profile("x", target: [(0, limits.target.bounds.lowerBound, limits.target.bounds.upperBound)], sensitivity: [(0, limits.sensitivity.bounds.lowerBound)], unit: .millimolesPerLiter)))
    }
}
