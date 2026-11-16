//
//  SmartwatchRemoteActions.swift
//  LoopKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation

/// Why a request from the watch (`SmartwatchManagerDelegate`'s actions) was
/// refused. Some cases come from the host's own checks, the rest from the
/// plugin's checks (`SmartwatchRemoteActionPolicy.swift`), so a plugin reports
/// both to the watch the same way.
public enum SmartwatchActionError: Error, Equatable {
    /// The action is off in the plugin, or the host doesn't offer it.
    case notAllowed
    /// The request is too old, or dated in the future.
    case expiredRequest
    /// Not a positive amount, or not one the host can use.
    case invalidAmount
    /// More than the host's maximum bolus or maximum carb entry.
    case exceedsMaximum
    /// A bolus above the recommendation the watch was shown.
    case exceedsRecommendation
    /// No recent glucose reading, as when the CGM is unavailable.
    case noRecentGlucose
    /// Too soon after the previous request of this kind.
    case rateLimited
    /// Watch boluses in the last 24 hours would exceed the daily limit.
    case dailyLimitReached
    /// No preset has this identifier.
    case unknownPreset
    /// A bolus is still being delivered; its result follows. Not a failure.
    case inProgress
    /// One of the host's own checks refused it (for example Trio's max IOB). The
    /// reason is also in the host's log.
    case refusedByHost(String)
    /// The pump was asked for a bolus and didn't accept it, including uncertain
    /// delivery. Every other case means nothing was sent to the pump.
    case deliveryFailed(String)
    /// The host couldn't do it (a carb entry or preset).
    case failed(String)
}
