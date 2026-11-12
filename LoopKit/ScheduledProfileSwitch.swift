//
//  ScheduledProfileSwitch.swift
//  LoopKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation

/// A weekly start of a therapy profile. The profile stays active until the next start or a switch made by hand.
/// `time` is wall-clock time in the time zone of the therapy schedules.
public struct ScheduledProfileSwitch: Codable, Equatable, Hashable, Identifiable {
    public let id: String
    public var profileName: String
    /// 1–7, Sunday = 1, the way `Calendar` numbers weekdays.
    public var weekday: Int
    /// Seconds from midnight, on a whole minute.
    public var time: TimeInterval
    /// A paused start does not run until it is resumed.
    public var paused: Bool

    public init(id: String = UUID().uuidString, profileName: String, weekday: Int, time: TimeInterval, paused: Bool = false) {
        self.id = id
        self.profileName = profileName
        self.weekday = weekday
        self.time = time
        self.paused = paused
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        profileName = try container.decode(String.self, forKey: .profileName)
        weekday = try container.decode(Int.self, forKey: .weekday)
        time = try container.decode(TimeInterval.self, forKey: .time)
        paused = try container.decodeIfPresent(Bool.self, forKey: .paused) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(profileName, forKey: .profileName)
        try container.encode(weekday, forKey: .weekday)
        try container.encode(Int(time), forKey: .time)
        if paused {
            try container.encode(paused, forKey: .paused)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case profileName = "profile"
        case weekday
        case time
        case paused
    }
}

extension ScheduledProfileSwitch {
    /// "Saturday 13:00".
    public var localizedWeekdayAndTime: String {
        String(format: LocalizedString("%1$@ %2$@", comment: "Weekday and time of a scheduled profile switch (1: weekday, 2: time)"), ScheduledProfileSwitches.weekdayName(weekday), ScheduledProfileSwitches.localizedTime(time))
    }

    /// "Weekend starts Saturday 13:00".
    public var localizedDescription: String {
        String(format: LocalizedString("%1$@ starts %2$@", comment: "A scheduled profile switch (1: profile name, 2: weekday and time)"), profileName, localizedWeekdayAndTime)
    }
}

/// A concrete instant a scheduled switch refers to.
public struct ScheduledProfileSwitchOccurrence: Equatable {
    public let entry: ScheduledProfileSwitch
    public let date: Date

    public init(entry: ScheduledProfileSwitch, date: Date) {
        self.entry = entry
        self.date = date
    }
}

/// What made the active profile change last.
public struct TherapyProfileSwitchTrigger: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let local = TherapyProfileSwitchTrigger(rawValue: "local")
    public static let remote = TherapyProfileSwitchTrigger(rawValue: "remote")
    public static let scheduled = TherapyProfileSwitchTrigger(rawValue: "scheduled")
}

public enum ScheduledProfileSwitchError: LocalizedError, Equatable {
    case tooMany
    case invalidWeekday
    case invalidTime
    case duplicateIdentifier
    case slotTaken(ScheduledProfileSwitch)
    case conflict

    public var errorDescription: String? {
        switch self {
        case .tooMany:
            return String(format: LocalizedString("There can be at most %1$d scheduled switches", comment: "Scheduled switch error: too many (1: maximum number)"), ScheduledProfileSwitches.maximumCount)
        case .invalidWeekday:
            return LocalizedString("A scheduled switch has no valid weekday", comment: "Scheduled switch error: weekday out of range")
        case .invalidTime:
            return LocalizedString("A scheduled switch has a time that is not on a whole minute of the day", comment: "Scheduled switch error: time out of range or not on a minute")
        case .duplicateIdentifier:
            return LocalizedString("Two scheduled switches have the same identifier", comment: "Scheduled switch error: duplicate identifier")
        case .slotTaken(let existing):
            return String(format: LocalizedString("%1$@ already starts %2$@", comment: "Scheduled switch error: another start has the same weekday and time (1: profile name, 2: weekday and time)"), existing.profileName, existing.localizedWeekdayAndTime)
        case .conflict:
            return LocalizedString("The scheduled switches changed on the phone after they were uploaded. Review them again and resend.", comment: "Scheduled switch error: fingerprint mismatch")
        }
    }
}

/// Operations on the list of scheduled switches.
public enum ScheduledProfileSwitches {
    public static let maximumCount = 14

    /// The occurrences of every start that is not paused in (`after`, `upTo`], newest first, in `timeZone`.
    public static func occurrences(of entries: [ScheduledProfileSwitch], after: Date, upTo: Date, timeZone: TimeZone) -> [ScheduledProfileSwitchOccurrence] {
        let calendar = calendar(in: timeZone)
        var occurrences: [ScheduledProfileSwitchOccurrence] = []
        for entry in entries where !entry.paused {
            var date = after
            while let next = nextDate(of: entry, after: date, calendar: calendar), next <= upTo {
                occurrences.append(ScheduledProfileSwitchOccurrence(entry: entry, date: next))
                date = next.addingTimeInterval(.hours(24))
            }
        }
        return occurrences.sorted { $0.date > $1.date }
    }

    /// The first occurrence after `date` of a start that is not paused.
    public static func next(in entries: [ScheduledProfileSwitch], after date: Date, timeZone: TimeZone) -> ScheduledProfileSwitchOccurrence? {
        let calendar = calendar(in: timeZone)
        return entries
            .filter { !$0.paused }
            .compactMap { entry in nextDate(of: entry, after: date, calendar: calendar).map { ScheduledProfileSwitchOccurrence(entry: entry, date: $0) } }
            .min { $0.date < $1.date }
    }

    /// Throws unless every entry is well formed, names one of `profileNames`, and has a weekday and time no other entry has.
    public static func validate(_ entries: [ScheduledProfileSwitch], profileNames: [String]) throws {
        guard entries.count <= maximumCount else {
            throw ScheduledProfileSwitchError.tooMany
        }
        guard Set(entries.map(\.id)).count == entries.count else {
            throw ScheduledProfileSwitchError.duplicateIdentifier
        }
        var slots: [String: ScheduledProfileSwitch] = [:]
        for entry in entries {
            guard (1...7).contains(entry.weekday) else {
                throw ScheduledProfileSwitchError.invalidWeekday
            }
            guard entry.time >= 0, entry.time < 86400, entry.time.truncatingRemainder(dividingBy: 60) == 0 else {
                throw ScheduledProfileSwitchError.invalidTime
            }
            guard profileNames.contains(entry.profileName) else {
                throw TherapyProfileError.notFound(entry.profileName)
            }
            let slot = "\(entry.weekday):\(Int(entry.time))"
            if let existing = slots[slot] {
                throw ScheduledProfileSwitchError.slotTaken(existing)
            }
            slots[slot] = entry
        }
    }

    /// The value a follower computes from the uploaded list and sends when it replaces the list, so the phone only
    /// replaces the list the follower reviewed. Each entry is `profile=<name>;weekday=<1–7>;date=-;time=<seconds>;paused=<bool>`;
    /// the sorted entries are joined with `|`, hashed with SHA-256, first 16 hex characters. Identifiers are not part of it.
    public static func fingerprint(_ entries: [ScheduledProfileSwitch]) -> String {
        TherapyProfile.fingerprint(canonical: canonicalFingerprintString(entries))
    }

    /// Different lists give different strings: the text between two entries is longer than
    /// `TherapyProfileValidator.maximumNameLength`, so no profile name can contain it.
    static func canonicalFingerprintString(_ entries: [ScheduledProfileSwitch]) -> String {
        entries
            .map { "profile=\($0.profileName);weekday=\($0.weekday);date=-;time=\(Int($0.time));paused=\($0.paused)" }
            .sorted()
            .joined(separator: "|")
    }

    /// The entries after the profile `from` is renamed to `to`.
    public static func renaming(_ entries: [ScheduledProfileSwitch], from: String, to: String) -> [ScheduledProfileSwitch] {
        entries.map { entry in
            var entry = entry
            if entry.profileName == from {
                entry.profileName = to
            }
            return entry
        }
    }

    /// The entries after the profile named `profile` is deleted.
    public static func removing(profile: String, from entries: [ScheduledProfileSwitch]) -> [ScheduledProfileSwitch] {
        entries.filter { $0.profileName != profile }
    }

    /// The entries as a week from Monday.
    public static func sortedAsWeek(_ entries: [ScheduledProfileSwitch]) -> [ScheduledProfileSwitch] {
        entries.sorted { lhs, rhs in
            let lhsDay = (lhs.weekday + 5) % 7
            let rhsDay = (rhs.weekday + 5) % 7
            return lhsDay != rhsDay ? lhsDay < rhsDay : lhs.time < rhs.time
        }
    }

    /// The weekday's name in the current locale, Sunday = 1.
    public static func weekdayName(_ weekday: Int, short: Bool = false) -> String {
        let symbols = short ? Calendar.current.shortStandaloneWeekdaySymbols : Calendar.current.standaloneWeekdaySymbols
        return symbols.indices.contains(weekday - 1) ? symbols[weekday - 1] : "\(weekday)"
    }

    /// The time of day, `seconds` from midnight, in the current locale.
    public static func localizedTime(_ seconds: TimeInterval) -> String {
        timeFormatter.string(from: Date(timeIntervalSinceReferenceDate: seconds))
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static func calendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// A time that does not exist on a day clocks spring forward is the first time after it; a time that repeats when
    /// clocks fall back is its first instance.
    private static func nextDate(of entry: ScheduledProfileSwitch, after date: Date, calendar: Calendar) -> Date? {
        let seconds = Int(entry.time)
        let components = DateComponents(hour: seconds / 3600, minute: (seconds % 3600) / 60, second: 0, weekday: entry.weekday)
        return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward)
    }
}
