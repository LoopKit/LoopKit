//
//  SmartwatchRemoteActionPolicy.swift
//  LoopKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation

/// How fresh a request from the watch must be: confirmed at most `maximumAge`
/// ago, and dated at most `maximumClockSkew` in the future. A host uses one
/// window for every remote action: it passes it to the bolus and carb policies
/// and checks mute and preset requests with it directly.
public struct SmartwatchRequestWindow: Equatable, Sendable {
    public var maximumAge: TimeInterval
    public var maximumClockSkew: TimeInterval

    public init(maximumAge: TimeInterval = 30, maximumClockSkew: TimeInterval = 5) {
        self.maximumAge = maximumAge
        self.maximumClockSkew = maximumClockSkew
    }

    public static let standard = SmartwatchRequestWindow()

    /// Whether a request confirmed at `requestedAt` may still run at `now`.
    public func contains(_ requestedAt: Date, now: Date) -> Bool {
        let age = now.timeIntervalSince(requestedAt)
        return age <= maximumAge && age >= -maximumClockSkew
    }
}

/// Every limit a host applies to one watch's remote actions, from
/// `SmartwatchManager.remoteActionLimits`: `.standard` unless the plugin declares
/// its own. One request window covers every action.
public struct SmartwatchRemoteActionLimits: Equatable, Sendable {
    public var requestWindow: SmartwatchRequestWindow
    public var bolus: SmartwatchBolusPolicy.Limits
    public var carbEntry: SmartwatchCarbEntryPolicy.Limits

    public init(
        requestWindow: SmartwatchRequestWindow = .standard,
        bolus: SmartwatchBolusPolicy.Limits = .standard,
        carbEntry: SmartwatchCarbEntryPolicy.Limits = .standard
    ) {
        self.requestWindow = requestWindow
        self.bolus = bolus
        self.carbEntry = carbEntry
    }

    public static let standard = SmartwatchRemoteActionLimits()

    /// The bolus limits with this request window.
    public var bolusPolicyLimits: SmartwatchBolusPolicy.Limits {
        var limits = bolus
        limits.requestWindow = requestWindow
        return limits
    }

    /// The carb entry limits with this request window.
    public var carbEntryPolicyLimits: SmartwatchCarbEntryPolicy.Limits {
        var limits = carbEntry
        limits.requestWindow = requestWindow
        return limits
    }
}

/// Decides whether a bolus requested from a watch plugin may be delivered.
///
/// A host calls `evaluate` from its `requestBolus`. The plugin authenticates the
/// request; this policy is the host's own check and does not trust the plugin's
/// numbers. It rejects requests that are not explicitly allowed, are old or made
/// against an older state, exceed the maximum bolus or the current recommendation,
/// or come too often. A forced request skips only the recommendation check.
///
/// A host can pass its own `Limits`, add checks before or after `evaluate`, or not
/// use this policy at all.
public struct SmartwatchBolusPolicy {
    /// How strict the policy is. `standard` is what Loop uses.
    public struct Limits: Equatable, Sendable {
        /// How fresh a request must be.
        public var requestWindow: SmartwatchRequestWindow
        /// A context older than this is rejected even if its token matches.
        public var maximumContextAge: TimeInterval
        /// Every watch bolus, forced ones too, is refused when the newest glucose
        /// reading is older than this: on the watch the user may not see that
        /// glucose is missing.
        public var maximumGlucoseAge: TimeInterval
        /// Minimum time between watch boluses.
        public var minimumInterval: TimeInterval
        /// Watch boluses in a rolling 24 hours may total at most this many maximum boluses.
        public var dailyLimitInMaximumBoluses: Double
        /// A request must quote the current context's token. Off only for a watch
        /// app that can't send it back: its requests are then checked against the
        /// current context, which must still be fresh.
        public var requiresContextToken: Bool
        /// A request may not exceed the recommendation unless it is forced. Off for
        /// a watch app that lets the user pick any amount up to the maximum bolus.
        public var capsAtRecommendation: Bool

        public init(
            requestWindow: SmartwatchRequestWindow = .standard,
            maximumContextAge: TimeInterval = 15 * 60,
            maximumGlucoseAge: TimeInterval = 15 * 60,
            minimumInterval: TimeInterval = 15 * 60,
            dailyLimitInMaximumBoluses: Double = 2,
            requiresContextToken: Bool = true,
            capsAtRecommendation: Bool = true
        ) {
            self.requestWindow = requestWindow
            self.maximumContextAge = maximumContextAge
            self.maximumGlucoseAge = maximumGlucoseAge
            self.minimumInterval = minimumInterval
            self.dailyLimitInMaximumBoluses = dailyLimitInMaximumBoluses
            self.requiresContextToken = requiresContextToken
            self.capsAtRecommendation = capsAtRecommendation
        }

        public static let standard = Limits()
    }

    /// A watch bolus the host delivered, for the rate limits. Codable, so a host
    /// can store its recent deliveries as it likes.
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
    /// Watch boluses are off unless the user turned them on and the plugin offers them.
    public var isAllowed: Bool
    /// The context the host last sent to the watch.
    public var currentContext: SmartwatchBolusContext?
    /// When the newest glucose reading was taken, CGM or entered by the user.
    public var latestGlucoseDate: Date?
    /// Watch boluses delivered recently, for the rate limits.
    public var recentDeliveries: [Delivery]
    /// Rounds to a volume the pump supports.
    public var roundToSupportedVolume: (Double) -> Double

    public init(
        limits: Limits = .standard,
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
    public func evaluate(_ request: SmartwatchBolusRequest, now: Date) -> Result<Double, SmartwatchBolusError> {
        guard isAllowed else {
            return .failure(.notAllowed)
        }
        guard request.units.isFinite, request.units > 0 else {
            return .failure(.invalidAmount)
        }
        guard limits.requestWindow.contains(request.requestedAt, now: now) else {
            return .failure(.expiredRequest)
        }
        guard let latestGlucoseDate, now.timeIntervalSince(latestGlucoseDate) <= limits.maximumGlucoseAge else {
            return .failure(.noRecentGlucose)
        }
        guard let context = currentContext,
              !limits.requiresContextToken || context.token == request.contextToken,
              now.timeIntervalSince(context.issuedAt) <= limits.maximumContextAge
        else {
            return .failure(.staleContext)
        }

        let units = roundToSupportedVolume(request.units)
        guard units > 0 else {
            return .failure(.invalidAmount)
        }
        guard let maximumBolus = context.maximumBolus, units <= maximumBolus + Self.tolerance else {
            return .failure(.exceedsMaximumBolus)
        }
        // The watch may bolus up to the recommendation the host showed it, rounded
        // the same way; never more, and nothing when the host recommends no bolus.
        // A forced request skips this check only.
        if !request.isForced, limits.capsAtRecommendation {
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

/// Hands out the bolus context a host sends to the watch, and keeps the state the
/// bolus checks need: a context is reused while its inputs are unchanged, spent
/// when a bolus starts, and a resend of the bolus being delivered is recognised.
/// Keep one per host and use it only from one actor (the main actor in Loop and Trio).
public struct SmartwatchBolusContextIssuer {
    /// What a context is computed from; a new token is issued when it changes.
    public struct Inputs: Equatable, Sendable {
        public var recommendedBolus: Double?
        public var maximumBolus: Double?
        public var supportedBolusVolumes: [Double]
        /// The newest glucose reading, so a new reading always gives a new token.
        public var latestGlucoseDate: Date?

        public init(recommendedBolus: Double?, maximumBolus: Double?, supportedBolusVolumes: [Double], latestGlucoseDate: Date?) {
            self.recommendedBolus = recommendedBolus
            self.maximumBolus = maximumBolus
            self.supportedBolusVolumes = supportedBolusVolumes
            self.latestGlucoseDate = latestGlucoseDate
        }
    }

    /// The context last handed out, until a bolus spends it.
    public private(set) var current: SmartwatchBolusContext?
    private var currentInputs: Inputs?
    private var deliveringToken: UUID?

    public init() {}

    /// The context to send: the current one while `inputs` are unchanged,
    /// otherwise a new one with a new token. A recommendation of 0 U or less
    /// counts as none.
    public mutating func context(for inputs: Inputs, now: Date) -> SmartwatchBolusContext {
        var inputs = inputs
        if let recommended = inputs.recommendedBolus, !(recommended > 0) {
            inputs.recommendedBolus = nil
        }
        if let current, inputs == currentInputs {
            return current
        }
        let context = SmartwatchBolusContext(
            token: UUID(),
            issuedAt: now,
            recommendedBolus: inputs.recommendedBolus,
            maximumBolus: inputs.maximumBolus,
            supportedBolusVolumes: inputs.supportedBolusVolumes
        )
        current = context
        currentInputs = inputs
        return context
    }

    /// Whether this request is a resend of the bolus being delivered. Answer it
    /// with `.inProgress`: its result follows, and a failure could lead the user
    /// to bolus again.
    public func isDelivering(_ request: SmartwatchBolusRequest) -> Bool {
        request.contextToken == deliveringToken
    }

    /// Spends the context, so the same request cannot deliver twice, and marks
    /// its bolus as being delivered. Call after the policy allowed the request.
    public mutating func beginDelivery(of request: SmartwatchBolusRequest) {
        current = nil
        currentInputs = nil
        deliveringToken = request.contextToken
    }

    /// Call when the pump has answered, whether or not the bolus was delivered.
    public mutating func endDelivery() {
        deliveringToken = nil
    }
}

/// Decides whether a carb entry requested from a watch plugin may be added. In a
/// closed loop the host may dose for it, so the rules are shared like the bolus
/// ones. A host can pass its own `Limits`, add checks, or not use this policy.
public struct SmartwatchCarbEntryPolicy {
    public struct Limits: Equatable, Sendable {
        /// How fresh a request must be.
        public var requestWindow: SmartwatchRequestWindow
        /// Minimum time between carb entries from the watch.
        public var minimumInterval: TimeInterval

        public init(requestWindow: SmartwatchRequestWindow = .standard, minimumInterval: TimeInterval = 15 * 60) {
            self.requestWindow = requestWindow
            self.minimumInterval = minimumInterval
        }

        public static let standard = Limits()
    }

    public var limits: Limits
    /// Carb entries are off unless the user turned them on and the plugin offers them.
    public var isAllowed: Bool
    /// The host's largest carb entry, in grams.
    public var maximumGrams: Double
    /// When the last carb entry from the watch was added.
    public var lastEntry: Date?

    public init(limits: Limits = .standard, isAllowed: Bool, maximumGrams: Double, lastEntry: Date?) {
        self.limits = limits
        self.isAllowed = isAllowed
        self.maximumGrams = maximumGrams
        self.lastEntry = lastEntry
    }

    /// The grams to add, or why not. A host takes its rate-limit slot (records the
    /// entry) before it stores the carbs, so a resend that arrives meanwhile is
    /// rate limited instead of added twice.
    public func evaluate(_ request: SmartwatchCarbEntryRequest, now: Date) -> Result<Double, SmartwatchCarbEntryError> {
        guard isAllowed else {
            return .failure(.notAllowed)
        }
        guard request.grams.isFinite, request.grams > 0 else {
            return .failure(.invalidAmount)
        }
        guard limits.requestWindow.contains(request.requestedAt, now: now) else {
            return .failure(.expiredRequest)
        }
        guard request.grams <= maximumGrams else {
            return .failure(.exceedsMaximum)
        }
        if let lastEntry, now.timeIntervalSince(lastEntry) < limits.minimumInterval {
            return .failure(.rateLimited)
        }
        return .success(request.grams)
    }
}
