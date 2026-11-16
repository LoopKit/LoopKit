//
//  SmartwatchRemoteActionPolicy.swift
//  LoopKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation

// Checks a watch plugin can apply before it asks the host to bolus or add carbs:
// how fresh a request and the newest glucose reading are, the maximum bolus and
// the host's current recommendation, and how often. How fresh is a range of allowed request
// ages in seconds (`ClosedRange<TimeInterval>`, as `-5...30`), which a plugin
// also checks mute and preset requests against. The host doesn't call these; it applies
// its own limits to every action (see `SmartwatchManagerDelegate`). There are no
// default limits: each plugin states its own, so the numbers are visible where
// they apply. Shared here so plugins with remote actions don't each copy them.

/// Decides whether a bolus requested on the watch may be passed to the host.
///
/// A plugin calls `evaluate` after it authenticated the request and before it
/// calls the host's `deliverBolus`, with the host's recommendation, maximum bolus
/// and bolus volumes read for this request. It rejects requests that are not
/// allowed, are old, come without recent glucose, exceed the maximum bolus or the
/// recommendation, or come too often. A forced request skips only the
/// recommendation check. The host still applies its own limits.
///
/// While a bolus it allowed is being delivered, a plugin answers further
/// requests with `.inProgress`: their result follows, and a failure could lead
/// the user to bolus again.
public struct SmartwatchBolusPolicy {
    /// How strict the policy is. No defaults: a plugin states each one.
    public struct Limits: Equatable, Sendable {
        /// How old a request may be, in seconds: confirmed on the watch at most
        /// `upperBound` ago, and dated at most `-lowerBound` in the future (as
        /// `-5...30`). Takes the date from the watch, not from when the command
        /// reached the phone, which can be much later.
        public var requestWindow: ClosedRange<TimeInterval>
        /// Every watch bolus, forced ones too, is refused when the newest glucose
        /// reading is older than this: on the watch the user may not see that
        /// glucose is missing.
        public var maximumGlucoseAge: TimeInterval
        /// Minimum time between watch boluses.
        public var minimumInterval: TimeInterval
        /// Watch boluses in a rolling 24 hours may total at most this many maximum boluses.
        public var dailyLimitInMaximumBoluses: Double
        /// A request may not exceed the recommendation unless it is forced. Off for
        /// a watch app that lets the user pick any amount up to the maximum bolus.
        public var capsAtRecommendation: Bool

        public init(
            requestWindow: ClosedRange<TimeInterval>,
            maximumGlucoseAge: TimeInterval,
            minimumInterval: TimeInterval,
            dailyLimitInMaximumBoluses: Double,
            capsAtRecommendation: Bool
        ) {
            self.requestWindow = requestWindow
            self.maximumGlucoseAge = maximumGlucoseAge
            self.minimumInterval = minimumInterval
            self.dailyLimitInMaximumBoluses = dailyLimitInMaximumBoluses
            self.capsAtRecommendation = capsAtRecommendation
        }
    }

    /// A watch bolus passed to the host, for the rate limits. Codable, so a plugin
    /// can store its recent deliveries as it likes. Store one with 0 units when the
    /// bolus starts (it counts toward `minimumInterval` even if delivery fails or is
    /// uncertain), and replace it with the delivered units once the host confirms.
    public struct Delivery: Equatable, Codable, Sendable {
        public let date: Date
        public let units: Double

        public init(date: Date, units: Double) {
            self.date = date
            self.units = units
        }
    }

    /// Tolerance for comparing rounded volumes.
    private static let tolerance = 0.0001

    public var limits: Limits
    /// Watch boluses are off unless the user turned them on in the plugin.
    public var isAllowed: Bool
    /// The host's manual bolus recommendation now, in units, read for this
    /// request. `nil`, or 0 U or less, when it recommends none: watch boluses are
    /// then refused unless forced.
    public var recommendedBolus: Double?
    /// The user's maximum bolus, in units; without one every watch bolus is refused.
    public var maximumBolus: Double?
    /// When the newest glucose reading was taken, CGM or entered by the user.
    public var latestGlucoseDate: Date?
    /// Watch boluses delivered recently, for the rate limits.
    public var recentDeliveries: [Delivery]
    /// Rounds to a volume the pump supports.
    public var roundToSupportedVolume: (Double) -> Double

    public init(
        limits: Limits,
        isAllowed: Bool,
        recommendedBolus: Double?,
        maximumBolus: Double?,
        latestGlucoseDate: Date?,
        recentDeliveries: [Delivery],
        roundToSupportedVolume: @escaping (Double) -> Double
    ) {
        self.limits = limits
        self.isAllowed = isAllowed
        self.recommendedBolus = recommendedBolus
        self.maximumBolus = maximumBolus
        self.latestGlucoseDate = latestGlucoseDate
        self.recentDeliveries = recentDeliveries
        self.roundToSupportedVolume = roundToSupportedVolume
    }

    /// The units to deliver, rounded to a supported volume, or why not.
    ///
    /// - Parameters:
    ///   - requestedAt: When the user confirmed the bolus on the watch.
    ///   - isForced: Skips only the recommendation check; every other check
    ///     (ages, maximum bolus, rate limits) still applies.
    public func evaluate(units requestedUnits: Double, requestedAt: Date, isForced: Bool, now: Date) -> Result<Double, SmartwatchActionError> {
        guard isAllowed else {
            return .failure(.notAllowed)
        }
        guard requestedUnits.isFinite, requestedUnits > 0 else {
            return .failure(.invalidAmount)
        }
        guard limits.requestWindow.contains(now.timeIntervalSince(requestedAt)) else {
            return .failure(.expiredRequest)
        }
        guard let latestGlucoseDate, now.timeIntervalSince(latestGlucoseDate) <= limits.maximumGlucoseAge else {
            return .failure(.noRecentGlucose)
        }
        let units = roundToSupportedVolume(requestedUnits)
        guard units > 0 else {
            return .failure(.invalidAmount)
        }
        guard let maximumBolus, units <= maximumBolus + Self.tolerance else {
            return .failure(.exceedsMaximum)
        }
        // The watch may bolus up to the host's recommendation, rounded the same
        // way; never more, and nothing when the host recommends no bolus.
        // A forced request skips this check only.
        if !isForced, limits.capsAtRecommendation {
            guard let recommended = recommendedBolus, recommended > 0,
                  units <= roundToSupportedVolume(recommended) + Self.tolerance
            else {
                return .failure(.exceedsRecommendation)
            }
        }

        if let last = recentDeliveries.map(\.date).max(), now.timeIntervalSince(last) < limits.minimumInterval {
            return .failure(.rateLimited)
        }
        let dayStart = now.addingTimeInterval(-24 * 60 * 60)
        let deliveredToday = recentDeliveries.filter { $0.date > dayStart }.reduce(0) { $0 + $1.units }
        guard deliveredToday + units <= maximumBolus * limits.dailyLimitInMaximumBoluses + Self.tolerance else {
            return .failure(.dailyLimitReached)
        }
        return .success(units)
    }
}

/// Decides whether a carb entry requested on the watch may be passed to the host.
/// In a closed loop the host may dose for it, so it gets checks like a bolus. The
/// host still applies its own maximum carb entry.
public struct SmartwatchCarbEntryPolicy {
    public struct Limits: Equatable, Sendable {
        /// How old a request may be, in seconds, as for a bolus.
        public var requestWindow: ClosedRange<TimeInterval>
        /// Minimum time between carb entries from the watch.
        public var minimumInterval: TimeInterval

        public init(requestWindow: ClosedRange<TimeInterval>, minimumInterval: TimeInterval) {
            self.requestWindow = requestWindow
            self.minimumInterval = minimumInterval
        }
    }

    public var limits: Limits
    /// Carb entries are off unless the user turned them on in the plugin.
    public var isAllowed: Bool
    /// The host's largest carb entry, in grams.
    public var maximumGrams: Double
    /// When the last carb entry from the watch was added.
    public var lastEntry: Date?

    public init(limits: Limits, isAllowed: Bool, maximumGrams: Double, lastEntry: Date?) {
        self.limits = limits
        self.isAllowed = isAllowed
        self.maximumGrams = maximumGrams
        self.lastEntry = lastEntry
    }

    /// The grams to add, or why not. A plugin takes its rate-limit slot (records the
    /// entry) before it asks the host to add the carbs, so a resend that arrives
    /// meanwhile is rate limited instead of added twice.
    ///
    /// - Parameter requestedAt: When the user confirmed the entry on the watch,
    ///   taken from the watch; the entry is dated then.
    public func evaluate(grams: Double, requestedAt: Date, now: Date) -> Result<Double, SmartwatchActionError> {
        guard isAllowed else {
            return .failure(.notAllowed)
        }
        guard grams.isFinite, grams > 0 else {
            return .failure(.invalidAmount)
        }
        guard limits.requestWindow.contains(now.timeIntervalSince(requestedAt)) else {
            return .failure(.expiredRequest)
        }
        guard grams <= maximumGrams else {
            return .failure(.exceedsMaximum)
        }
        if let lastEntry, now.timeIntervalSince(lastEntry) < limits.minimumInterval {
            return .failure(.rateLimited)
        }
        return .success(grams)
    }
}
