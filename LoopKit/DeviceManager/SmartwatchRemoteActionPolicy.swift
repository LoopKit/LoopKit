//
//  SmartwatchRemoteActionPolicy.swift
//  LoopKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation

// Checks a watch plugin can apply before it asks the host to bolus or add carbs:
// how fresh a request is, whether it was made against what the watch was shown,
// the recommendation cap, and how often. How fresh is a range of allowed request
// ages in seconds (`ClosedRange<TimeInterval>`, as `-5...30`), which a plugin
// also checks mute and preset requests against. The host doesn't call these; it applies
// its own limits to every action (see `SmartwatchManagerDelegate`). There are no
// default limits: each plugin states its own, so the numbers are visible where
// they apply. Shared here so plugins with remote actions don't each copy them.

/// What the watch was shown to pick a bolus: the recommendation, the maximum
/// bolus and the pump's volumes at one moment.
public struct SmartwatchBolusContext: Equatable, Sendable {
    /// When this context was issued.
    public var issuedAt: Date

    /// The host's manual bolus recommendation, in units. `nil` when it
    /// recommends none; watch boluses are then refused unless forced.
    public var recommendedBolus: Double?

    /// The user's maximum bolus, in units.
    public var maximumBolus: Double?

    /// Bolus volumes the pump can deliver, in units.
    public var supportedBolusVolumes: [Double]

    public init(issuedAt: Date, recommendedBolus: Double?, maximumBolus: Double?, supportedBolusVolumes: [Double]) {
        self.issuedAt = issuedAt
        self.recommendedBolus = recommendedBolus
        self.maximumBolus = maximumBolus
        self.supportedBolusVolumes = supportedBolusVolumes
    }

    /// The pump's smallest bolus step in units, for a watch that picks an amount.
    public var bolusIncrement: Double? {
        let steps = zip(supportedBolusVolumes.dropFirst(), supportedBolusVolumes).map { $0 - $1 }.filter { $0 > 0 }
        return steps.min() ?? supportedBolusVolumes.first
    }
}

/// Decides whether a bolus requested on the watch may be passed to the host.
///
/// A plugin calls `evaluate` after it authenticated the request and before it
/// calls the host's `deliverBolus`. It rejects requests that are not allowed, are
/// old, come without a current context, exceed the maximum bolus or the current
/// recommendation, or come too often. A forced request skips
/// only the recommendation check. The host still applies its own limits.
public struct SmartwatchBolusPolicy {
    /// How strict the policy is. No defaults: a plugin states each one.
    public struct Limits: Equatable, Sendable {
        /// How old a request may be, in seconds: confirmed on the watch at most
        /// `upperBound` ago, and dated at most `-lowerBound` in the future (as
        /// `-5...30`). Takes the date from the watch, not from when the command
        /// reached the phone, which can be much later.
        public var requestWindow: ClosedRange<TimeInterval>
        /// A context older than this is rejected.
        public var maximumContextAge: TimeInterval
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
            maximumContextAge: TimeInterval,
            maximumGlucoseAge: TimeInterval,
            minimumInterval: TimeInterval,
            dailyLimitInMaximumBoluses: Double,
            capsAtRecommendation: Bool
        ) {
            self.requestWindow = requestWindow
            self.maximumContextAge = maximumContextAge
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
    /// The context the watch was last shown.
    public var currentContext: SmartwatchBolusContext?
    /// When the newest glucose reading was taken, CGM or entered by the user.
    public var latestGlucoseDate: Date?
    /// Watch boluses delivered recently, for the rate limits.
    public var recentDeliveries: [Delivery]
    /// Rounds to a volume the pump supports.
    public var roundToSupportedVolume: (Double) -> Double

    public init(
        limits: Limits,
        isAllowed: Bool,
        currentContext: SmartwatchBolusContext?,
        latestGlucoseDate: Date?,
        recentDeliveries: [Delivery],
        roundToSupportedVolume: @escaping (Double) -> Double
    ) {
        self.limits = limits
        self.isAllowed = isAllowed
        self.currentContext = currentContext
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
        guard let context = currentContext,
              now.timeIntervalSince(context.issuedAt) <= limits.maximumContextAge
        else {
            return .failure(.staleContext)
        }

        let units = roundToSupportedVolume(requestedUnits)
        guard units > 0 else {
            return .failure(.invalidAmount)
        }
        guard let maximumBolus = context.maximumBolus, units <= maximumBolus + Self.tolerance else {
            return .failure(.exceedsMaximum)
        }
        // The watch may bolus up to the recommendation it was shown, rounded
        // the same way; never more, and nothing when the host recommends no bolus.
        // A forced request skips this check only.
        if !isForced, limits.capsAtRecommendation {
            guard let recommended = context.recommendedBolus,
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

/// Hands out the bolus context a plugin shows on the watch, and keeps the state
/// the bolus checks need: a context is reused while its inputs are unchanged,
/// spent when a bolus starts, and a request while a bolus is being delivered is
/// recognised. Issue a context again after every glucose or loop change, from
/// the host's recommendation, maximum bolus and bolus volumes, so a bolus is
/// checked against the current state. Keep one per manager and use it only from
/// one actor.
public struct SmartwatchBolusContextIssuer {
    /// The context last handed out, until a bolus spends it.
    public private(set) var current: SmartwatchBolusContext?
    /// The newest glucose reading when `current` was issued, so a new reading
    /// always gives a new context.
    private var currentLatestGlucoseDate: Date?
    /// Whether a bolus is being delivered: from `beginDelivery()` until
    /// `endDelivery()`. Answer a request meanwhile with `.inProgress`: its result
    /// follows, and a failure could lead the user to bolus again.
    public private(set) var isDelivering = false

    public init() {}

    /// The context to send: the current one while its inputs are unchanged,
    /// otherwise a new one issued `now`. A recommendation of 0 U or less
    /// counts as none.
    public mutating func context(recommendedBolus: Double?, maximumBolus: Double?, supportedBolusVolumes: [Double], latestGlucoseDate: Date?, now: Date) -> SmartwatchBolusContext {
        let recommendedBolus = recommendedBolus.flatMap { $0 > 0 ? $0 : nil }
        if let current,
           current.recommendedBolus == recommendedBolus,
           current.maximumBolus == maximumBolus,
           current.supportedBolusVolumes == supportedBolusVolumes,
           currentLatestGlucoseDate == latestGlucoseDate {
            return current
        }
        let context = SmartwatchBolusContext(
            issuedAt: now,
            recommendedBolus: recommendedBolus,
            maximumBolus: maximumBolus,
            supportedBolusVolumes: supportedBolusVolumes
        )
        current = context
        currentLatestGlucoseDate = latestGlucoseDate
        return context
    }

    /// Spends the context, so the same request cannot deliver twice, and marks
    /// a bolus as being delivered. Call after the policy allowed the request.
    public mutating func beginDelivery() {
        current = nil
        currentLatestGlucoseDate = nil
        isDelivering = true
    }

    /// Call when the pump has answered, whether or not the bolus was delivered.
    public mutating func endDelivery() {
        isDelivering = false
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
