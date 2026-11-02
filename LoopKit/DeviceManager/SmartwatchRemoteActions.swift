//
//  SmartwatchRemoteActions.swift
//  LoopKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation

// Requests a watch plugin may send its host (steps 3 and 5): each only with its
// capability and the user's permission. The rules hosts apply are in
// `SmartwatchRemoteActionPolicy.swift`.

/// What a watch needs to request a bolus, sent with `.remoteBolus`.
public struct SmartwatchBolusContext: Equatable {
    /// Identifies the state the recommendation was computed from. A request must
    /// echo it, and the host rejects requests made against an older state.
    public var token: UUID

    /// When the host issued this context.
    public var issuedAt: Date

    /// The current manual bolus recommendation, in units. `nil` when the host
    /// recommends no bolus; the host then rejects watch boluses.
    public var recommendedBolus: Double?

    /// The user's maximum bolus, in units.
    public var maximumBolus: Double?

    /// Bolus volumes the pump can deliver, in units.
    public var supportedBolusVolumes: [Double]

    public init(token: UUID, issuedAt: Date, recommendedBolus: Double?, maximumBolus: Double?, supportedBolusVolumes: [Double]) {
        self.token = token
        self.issuedAt = issuedAt
        self.recommendedBolus = recommendedBolus
        self.maximumBolus = maximumBolus
        self.supportedBolusVolumes = supportedBolusVolumes
    }
}

/// A bolus the user confirmed on the watch, after the plugin authenticated it.
public struct SmartwatchBolusRequest: Equatable {
    public var units: Double
    /// `SmartwatchBolusContext.token` from the snapshot the watch showed.
    public var contextToken: UUID
    /// When the user confirmed the bolus on the watch. Take it from the watch, not from when the
    /// command reached the phone, which can be much later; hosts refuse requests
    /// older than 30 seconds.
    public var requestedAt: Date
    /// Asks the host to skip only its recommendation check; every other check
    /// (permission, ages, maximum bolus, rate limits) still applies.
    public var isForced: Bool

    public init(units: Double, contextToken: UUID, requestedAt: Date, isForced: Bool = false) {
        self.units = units
        self.contextToken = contextToken
        self.requestedAt = requestedAt
        self.isForced = isForced
    }
}

/// A mute the user confirmed on the watch, sent with `.remoteMute`.
public struct SmartwatchAlertMuteRequest: Equatable {
    /// How long to mute the host's alerts.
    public var duration: TimeInterval
    /// When the user confirmed it on the watch. Take it from the watch, not from when the
    /// command reached the phone, which can be much later; hosts refuse requests
    /// older than 30 seconds.
    public var requestedAt: Date

    public init(duration: TimeInterval, requestedAt: Date) {
        self.duration = duration
        self.requestedAt = requestedAt
    }
}

/// Why the host refused a mute request from the watch.
public enum SmartwatchAlertMuteError: Error, Equatable {
    /// The user hasn't allowed muting from the watch, or the plugin lacks `.remoteMute`.
    case notAllowed
    /// The request is too old, or dated in the future.
    case expiredRequest
}

/// Carbs the user confirmed on the watch, sent with `.remoteCarbs`.
public struct SmartwatchCarbEntryRequest: Equatable {
    public var grams: Double
    /// When the user confirmed the entry on the watch. Take it from the watch, not from when the
    /// command reached the phone, which can be much later; hosts refuse requests
    /// older than 30 seconds.
    public var requestedAt: Date

    public init(grams: Double, requestedAt: Date) {
        self.grams = grams
        self.requestedAt = requestedAt
    }
}

/// Why the host did not add a carb entry the watch asked for.
public enum SmartwatchCarbEntryError: Error, Equatable {
    /// The user hasn't allowed carb entries from the watch, or the plugin lacks `.remoteCarbs`.
    case notAllowed
    /// The request is too old, or dated in the future.
    case expiredRequest
    /// Not a positive amount.
    case invalidAmount
    /// More than the host's maximum carb entry.
    case exceedsMaximum
    /// Another carb entry from the watch was added too recently.
    case rateLimited
    case failed(String)
}

/// A preset the watch can start: an override or a temp target.
public struct SmartwatchPreset: Equatable, Sendable {
    /// The host's identifier for the preset; send it back to start it.
    public var id: String
    public var name: String
    /// Whether this preset is running now.
    public var isActive: Bool
    /// How long the preset runs when started. `nil` means until it is ended.
    public var duration: TimeInterval?

    public init(id: String, name: String, isActive: Bool, duration: TimeInterval?) {
        self.id = id
        self.name = name
        self.isActive = isActive
        self.duration = duration
    }
}

/// What the watch asks for a preset.
public enum SmartwatchPresetAction: Equatable, Sendable {
    /// Start the preset with this `SmartwatchPreset.id`, replacing any running one.
    case activate(presetID: String)
    /// End the running preset.
    case cancel
}

/// An override the user started or ended on the watch, sent with `.remoteOverride`.
public struct SmartwatchOverrideRequest: Equatable {
    public var action: SmartwatchPresetAction
    /// When the user confirmed it on the watch. Take it from the watch, not from when the
    /// command reached the phone, which can be much later; hosts refuse requests
    /// older than 30 seconds.
    public var requestedAt: Date

    public init(action: SmartwatchPresetAction, requestedAt: Date) {
        self.action = action
        self.requestedAt = requestedAt
    }
}

/// A temp target the user started or ended on the watch, sent with `.remoteTempTarget`.
public struct SmartwatchTempTargetRequest: Equatable {
    public var action: SmartwatchPresetAction
    /// When the user confirmed it on the watch. Take it from the watch, not from when the
    /// command reached the phone, which can be much later; hosts refuse requests
    /// older than 30 seconds.
    public var requestedAt: Date

    public init(action: SmartwatchPresetAction, requestedAt: Date) {
        self.action = action
        self.requestedAt = requestedAt
    }
}

/// Why the host did not start or end an override or temp target.
public enum SmartwatchPresetError: Error, Equatable {
    /// The user hasn't allowed it from the watch, or the plugin lacks the capability.
    case notAllowed
    /// The request is too old, or dated in the future.
    case expiredRequest
    /// No preset has this identifier.
    case unknownPreset
    case failed(String)
}

/// Why the host did not deliver a watch bolus.
public enum SmartwatchBolusError: Error, Equatable {
    /// Watch boluses are turned off, or the plugin lacks `.remoteBolus`.
    case notAllowed
    case invalidAmount
    /// The request is too old, or dated in the future.
    case expiredRequest
    /// The request was made against an older state than the current one.
    case staleContext
    /// No glucose reading in the last 15 minutes, as when the CGM is unavailable.
    case noRecentGlucose
    case exceedsMaximumBolus
    case exceedsRecommendation
    /// Too soon after the previous watch bolus.
    case rateLimited
    /// Watch boluses in the last 24 hours would exceed the daily limit.
    case dailyLimitReached
    /// One of the host's own checks refused it, beyond `SmartwatchBolusPolicy`
    /// (for example Trio's max IOB). The reason is also in the host's log.
    case refusedByHost(String)
    /// The same bolus is still being delivered; its result follows. Not a failure.
    case inProgress
    case deliveryFailed(String)
}
