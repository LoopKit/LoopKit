//
//  SmartwatchRemoteActions.swift
//  LoopKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation

// What a watch plugin asks of its host (`SmartwatchManagerDelegate`'s actions),
// and why a request is refused. Some errors come from the host's own checks, the
// rest from the plugin's checks (`SmartwatchRemoteActionPolicy.swift`), so a
// plugin reports both to the watch the same way.

/// What the watch asks for a preset.
public enum SmartwatchPresetAction: Equatable, Sendable {
    /// Start the preset with this `TemporaryPreset.id`, replacing any running one.
    case activate(presetID: String)
    /// End the running preset.
    case cancel
}

/// Why a mute request from the watch was refused.
public enum SmartwatchAlertMuteError: Error, Equatable {
    /// Muting from the watch is off in the plugin, or the host doesn't offer it.
    case notAllowed
    /// The request is too old, or dated in the future.
    case expiredRequest
}

/// Why a carb entry the watch asked for was not added.
public enum SmartwatchCarbEntryError: Error, Equatable {
    /// Carb entries from the watch are off in the plugin, or the host doesn't offer them.
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

/// Why an override or temp target was not started or ended.
public enum SmartwatchPresetError: Error, Equatable {
    /// Presets from the watch are off in the plugin, or the host doesn't offer them.
    case notAllowed
    /// The request is too old, or dated in the future.
    case expiredRequest
    /// No preset has this identifier.
    case unknownPreset
    case failed(String)
}

/// Why a watch bolus was not delivered.
public enum SmartwatchBolusError: Error, Equatable {
    /// Watch boluses are off in the plugin, or the host doesn't offer them.
    case notAllowed
    case invalidAmount
    /// The request is too old, or dated in the future.
    case expiredRequest
    /// The request was made against an older state than the current one.
    case staleContext
    /// No recent glucose reading, as when the CGM is unavailable.
    case noRecentGlucose
    case exceedsMaximumBolus
    case exceedsRecommendation
    /// Too soon after the previous watch bolus.
    case rateLimited
    /// Watch boluses in the last 24 hours would exceed the daily limit.
    case dailyLimitReached
    /// One of the host's own checks refused it (for example Trio's max IOB). The
    /// reason is also in the host's log.
    case refusedByHost(String)
    /// A bolus is still being delivered; its result follows. Not a failure.
    case inProgress
    case deliveryFailed(String)
}
