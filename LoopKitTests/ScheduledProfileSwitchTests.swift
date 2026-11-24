//
//  ScheduledProfileSwitchTests.swift
//  LoopKitTests
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit

final class ScheduledProfileSwitchTests: XCTestCase {

    private let stockholm = TimeZone(identifier: "Europe/Stockholm")!
    private let newYork = TimeZone(identifier: "America/New_York")!

    private func date(_ string: String, in timeZone: TimeZone) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: string)!
    }

    // 2026-11-14 is a Saturday (weekday 7), 2026-11-16 a Monday (weekday 2).
    private let weekend = ScheduledProfileSwitch(id: "w", profileName: "Weekend", weekday: 7, time: .hours(7))
    private let school = ScheduledProfileSwitch(id: "s", profileName: "Default", weekday: 2, time: .hours(6))

    // MARK: Fingerprint

    func testFingerprintMatchesSharedTestVectors() {
        XCTAssertEqual(ScheduledProfileSwitches.canonicalFingerprintString([weekend, school]),
                       "profile=Default;weekday=2;date=-;time=21600;paused=false|profile=Weekend;weekday=7;date=-;time=25200;paused=false")
        XCTAssertEqual(ScheduledProfileSwitches.fingerprint([weekend, school]), "1f4d16404c846d2f")

        var pausedWeekend = weekend
        pausedWeekend.paused = true
        var pausedSchool = school
        pausedSchool.paused = true
        XCTAssertEqual(ScheduledProfileSwitches.canonicalFingerprintString([pausedWeekend, pausedSchool]),
                       "profile=Default;weekday=2;date=-;time=21600;paused=true|profile=Weekend;weekday=7;date=-;time=25200;paused=true")
        XCTAssertEqual(ScheduledProfileSwitches.fingerprint([pausedWeekend, pausedSchool]), "bc784950a457ba2c")

        XCTAssertEqual(ScheduledProfileSwitches.fingerprint([]), "e3b0c44298fc1c14")
    }

    func testANameCanNotHoldTheTextBetweenTwoCanonicalEntries() {
        let between = ";weekday=1;date=-;time=0;paused=true|profile="
        XCTAssertGreaterThan(between.count, TherapyProfileValidator.maximumNameLength)
    }

    func testFingerprintIgnoresIdentifiersAndOrder() {
        let renumbered = ScheduledProfileSwitch(id: "other", profileName: "Weekend", weekday: 7, time: .hours(7))
        XCTAssertEqual(ScheduledProfileSwitches.fingerprint([school, renumbered]), ScheduledProfileSwitches.fingerprint([weekend, school]))
    }

    // MARK: Compact JSON

    func testCompactJSONRoundTripsAndOmitsPausedWhenFalse() throws {
        var paused = weekend
        paused.paused = true
        let data = try JSONEncoder().encode([school, paused])
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        XCTAssertEqual(json[0]["profile"] as? String, "Default")
        XCTAssertEqual(json[0]["time"] as? Int, 21600)
        XCTAssertNil(json[0]["paused"])
        XCTAssertEqual(json[1]["paused"] as? Bool, true)
        XCTAssertEqual(try JSONDecoder().decode([ScheduledProfileSwitch].self, from: data), [school, paused])

        let compact = #"{"id":"5A3D9D6E-1C7F-4A52-9C1D-2B3F9E0F7A11","profile":"Weekend","weekday":7,"time":25200,"paused":true}"#
        let decoded = try JSONDecoder().decode(ScheduledProfileSwitch.self, from: Data(compact.utf8))
        XCTAssertEqual(decoded, ScheduledProfileSwitch(id: "5A3D9D6E-1C7F-4A52-9C1D-2B3F9E0F7A11", profileName: "Weekend", weekday: 7, time: 25200, paused: true))
    }

    // MARK: Occurrences

    func testOccurrencesAcrossAWeekNewestFirst() {
        let entries = [weekend, school]
        let occurrences = ScheduledProfileSwitches.occurrences(of: entries, after: date("2026-11-13 12:00", in: stockholm), upTo: date("2026-11-23 06:00", in: stockholm), timeZone: stockholm)
        XCTAssertEqual(occurrences.map(\.date), [date("2026-11-23 06:00", in: stockholm), date("2026-11-21 07:00", in: stockholm), date("2026-11-16 06:00", in: stockholm), date("2026-11-14 07:00", in: stockholm)])
        XCTAssertEqual(occurrences.map(\.entry.id), ["s", "w", "s", "w"])
    }

    func testOccurrenceWindowExcludesItsStartAndIncludesItsEnd() {
        let at = date("2026-11-14 07:00", in: stockholm)
        XCTAssertEqual(ScheduledProfileSwitches.occurrences(of: [weekend], after: at, upTo: at.addingTimeInterval(.hours(1)), timeZone: stockholm), [])
        XCTAssertEqual(ScheduledProfileSwitches.occurrences(of: [weekend], after: at.addingTimeInterval(-1), upTo: at, timeZone: stockholm).map(\.date), [at])
    }

    func testOccurrencesUseTheGivenTimeZone() {
        let occurrences = ScheduledProfileSwitches.occurrences(of: [weekend], after: date("2026-11-13 00:00", in: newYork), upTo: date("2026-11-15 00:00", in: newYork), timeZone: newYork)
        XCTAssertEqual(occurrences.map(\.date), [date("2026-11-14 07:00", in: newYork)])
        XCTAssertNotEqual(date("2026-11-14 07:00", in: newYork), date("2026-11-14 07:00", in: stockholm))
    }

    func testSpringForwardRunsAtTheFirstTimeAfterTheMissingHour() {
        // 2026-03-29 is a Sunday; Stockholm skips 02:00–03:00.
        let night = ScheduledProfileSwitch(profileName: "Night", weekday: 1, time: .minutes(150))
        let occurrences = ScheduledProfileSwitches.occurrences(of: [night], after: date("2026-03-28 12:00", in: stockholm), upTo: date("2026-03-29 12:00", in: stockholm), timeZone: stockholm)
        XCTAssertEqual(occurrences.map(\.date), [date("2026-03-29 03:00", in: stockholm)])
    }

    func testFallBackRunsOnce() {
        // 2026-10-25 is a Sunday; Stockholm repeats 02:00–03:00.
        let night = ScheduledProfileSwitch(profileName: "Night", weekday: 1, time: .minutes(150))
        let occurrences = ScheduledProfileSwitches.occurrences(of: [night], after: date("2026-10-24 12:00", in: stockholm), upTo: date("2026-10-25 12:00", in: stockholm), timeZone: stockholm)
        XCTAssertEqual(occurrences.count, 1)
        XCTAssertEqual(occurrences.first?.date, Date(timeIntervalSince1970: 1_792_888_200))
    }

    func testPausedEntryHasNoOccurrencesAndNextSkipsIt() {
        var pausedWeekend = weekend
        pausedWeekend.paused = true
        let after = date("2026-11-13 12:00", in: stockholm)
        XCTAssertEqual(ScheduledProfileSwitches.occurrences(of: [pausedWeekend, school], after: after, upTo: date("2026-11-16 12:00", in: stockholm), timeZone: stockholm).map(\.entry.id), ["s"])
        XCTAssertEqual(ScheduledProfileSwitches.next(in: [pausedWeekend, school], after: after, timeZone: stockholm), ScheduledProfileSwitchOccurrence(entry: school, date: date("2026-11-16 06:00", in: stockholm)))
        XCTAssertEqual(ScheduledProfileSwitches.next(in: [weekend, school], after: after, timeZone: stockholm)?.entry, weekend)
        XCTAssertNil(ScheduledProfileSwitches.next(in: [pausedWeekend], after: after, timeZone: stockholm))
    }

    // MARK: Validation

    func testValidListPasses() throws {
        try ScheduledProfileSwitches.validate([weekend, school], profileNames: ["Default", "Weekend"])
        try ScheduledProfileSwitches.validate([], profileNames: ["Default"])
    }

    func testValidationRejects() {
        let names = ["Default", "Weekend"]
        func assertRejects(_ entries: [ScheduledProfileSwitch], _ expected: Error, file: StaticString = #filePath, line: UInt = #line) {
            XCTAssertThrowsError(try ScheduledProfileSwitches.validate(entries, profileNames: names), file: file, line: line) { error in
                XCTAssertEqual(error.localizedDescription, expected.localizedDescription, file: file, line: line)
            }
        }
        let fifteen = (0..<15).map { ScheduledProfileSwitch(profileName: "Default", weekday: $0 % 7 + 1, time: TimeInterval($0) * 3600) }
        assertRejects(fifteen, ScheduledProfileSwitchError.tooMany)
        assertRejects([ScheduledProfileSwitch(profileName: "Sick", weekday: 2, time: 0)], TherapyProfileError.notFound("Sick"))
        let sameSlot = ScheduledProfileSwitch(profileName: "Default", weekday: 7, time: .hours(7))
        assertRejects([weekend, sameSlot], ScheduledProfileSwitchError.slotTaken(weekend))
        let duplicate = ScheduledProfileSwitch(profileName: "Weekend", weekday: 7, time: .hours(7))
        assertRejects([weekend, duplicate], ScheduledProfileSwitchError.slotTaken(weekend))
        assertRejects([ScheduledProfileSwitch(profileName: "Default", weekday: 2, time: 90)], ScheduledProfileSwitchError.invalidTime)
        assertRejects([ScheduledProfileSwitch(profileName: "Default", weekday: 2, time: 86400)], ScheduledProfileSwitchError.invalidTime)
        assertRejects([ScheduledProfileSwitch(profileName: "Default", weekday: 8, time: 0)], ScheduledProfileSwitchError.invalidWeekday)
        assertRejects([weekend, ScheduledProfileSwitch(id: "w", profileName: "Default", weekday: 2, time: 0)], ScheduledProfileSwitchError.duplicateIdentifier)
        XCTAssertNoThrow(try ScheduledProfileSwitches.validate(Array(fifteen.prefix(14)), profileNames: names))
    }

    // MARK: Rename and delete

    func testRenamingAndRemoving() {
        XCTAssertEqual(ScheduledProfileSwitches.renaming([weekend, school], from: "Weekend", to: "Saturday").map(\.profileName), ["Saturday", "Default"])
        XCTAssertEqual(ScheduledProfileSwitches.renaming([weekend, school], from: "Weekend", to: "Saturday").map(\.id), ["w", "s"])
        XCTAssertEqual(ScheduledProfileSwitches.removing(profile: "Weekend", from: [weekend, school]), [school])
    }

    func testSortedAsWeekStartsOnMonday() {
        let sunday = ScheduledProfileSwitch(id: "sun", profileName: "Default", weekday: 1, time: 0)
        let mondayLate = ScheduledProfileSwitch(id: "mon", profileName: "Weekend", weekday: 2, time: .hours(20))
        XCTAssertEqual(ScheduledProfileSwitches.sortedAsWeek([sunday, weekend, mondayLate, school]).map(\.id), ["s", "mon", "w", "sun"])
    }

    // MARK: StoredSettings

    private var storedSettingsWithSwitches: StoredSettings {
        StoredSettings(date: Date(timeIntervalSince1970: 1_700_000_000),
                       bloodGlucoseUnit: .milligramsPerDeciliter,
                       scheduledSwitches: [weekend, school],
                       scheduledSwitchesSettledAt: Date(timeIntervalSince1970: 1_700_000_100),
                       activeProfileSwitchTrigger: .scheduled,
                       syncIdentifier: UUID())
    }

    func testStoredSettingsWithScheduledSwitchesRoundTrips() throws {
        let original = storedSettingsWithSwitches
        let decoded = try PropertyListDecoder().decode(StoredSettings.self, from: PropertyListEncoder().encode(original))
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.activeProfileSwitchTrigger, .scheduled)
    }

    func testStoredSettingsWithoutScheduledSwitchKeysDecodes() throws {
        var original = storedSettingsWithSwitches
        original.scheduledSwitches = []
        original.scheduledSwitchesSettledAt = nil
        original.activeProfileSwitchTrigger = nil
        let data = try PropertyListEncoder().encode(original)
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertNil(plist["scheduledSwitches"])
        XCTAssertNil(plist["scheduledSwitchesSettledAt"])
        XCTAssertNil(plist["activeProfileSwitchTrigger"])

        let decoded = try PropertyListDecoder().decode(StoredSettings.self, from: data)
        XCTAssertEqual(decoded.scheduledSwitches, [])
        XCTAssertNil(decoded.scheduledSwitchesSettledAt)
        XCTAssertNil(decoded.activeProfileSwitchTrigger)
        XCTAssertEqual(decoded, original)
    }

    /// A record with the scheduled switch keys is the record without them plus keys that a reader without them ignores.
    func testStoredSettingsWithScheduledSwitchesReadsAsTheRecordWithoutThem() throws {
        var withSwitches = storedSettingsWithSwitches
        var plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: PropertyListEncoder().encode(withSwitches), format: nil) as? [String: Any])
        XCTAssertNotNil(plist.removeValue(forKey: "scheduledSwitches"))
        XCTAssertNotNil(plist.removeValue(forKey: "scheduledSwitchesSettledAt"))
        XCTAssertEqual(plist.removeValue(forKey: "activeProfileSwitchTrigger") as? String, "scheduled")

        withSwitches.scheduledSwitches = []
        withSwitches.scheduledSwitchesSettledAt = nil
        withSwitches.activeProfileSwitchTrigger = nil
        let withoutSwitches = try XCTUnwrap(PropertyListSerialization.propertyList(from: PropertyListEncoder().encode(withSwitches), format: nil) as? [String: Any])
        XCTAssertEqual(plist as NSDictionary, withoutSwitches as NSDictionary)
    }

    func testStoredSettingsSkipsAnUnreadableScheduledSwitch() throws {
        var plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: PropertyListEncoder().encode(storedSettingsWithSwitches), format: nil) as? [String: Any])
        var entries = try XCTUnwrap(plist["scheduledSwitches"] as? [[String: Any]])
        entries[0]["weekday"] = "Saturday"
        entries.append(["id": "once", "profile": "Sick", "date": "2026-11-14", "time": 28800])
        plist["scheduledSwitches"] = entries
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)

        let decoded = try PropertyListDecoder().decode(StoredSettings.self, from: data)
        XCTAssertEqual(decoded.scheduledSwitches, [school])
        XCTAssertEqual(decoded.scheduledSwitchesSettledAt, Date(timeIntervalSince1970: 1_700_000_100))
    }
}
