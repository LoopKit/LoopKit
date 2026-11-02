//
//  SmartwatchManager.swift
//  LoopKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation

// This protocol family is intentionally free of `DeviceManager` and of any other
// LoopKit type, so the same plugin builds against any AID's LoopKit (Loop loads it
// dynamically; Trio imports it statically). The UI layer (`SmartwatchManagerUI` in
// LoopKitUI) adds `DeviceManagerUI`, so a plugin conforms to `DeviceManager` in its
// own extension.

/// What a watch plugin shows. The host only builds and sends the parts a
/// plugin declares.
public struct SmartwatchCapabilities: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// The latest glucose reading.
    public static let glucose = SmartwatchCapabilities(rawValue: 1 << 0)
    /// Recent glucose readings, for a graph.
    public static let history = SmartwatchCapabilities(rawValue: 1 << 1)
    /// Predicted glucose from the last loop run.
    public static let prediction = SmartwatchCapabilities(rawValue: 1 << 2)
    /// Insulin and carbs on board, last loop completion and closed loop state.
    public static let loopStatus = SmartwatchCapabilities(rawValue: 1 << 3)
    /// Host-issued alerts: the host forwards its own alerts to the watch as they
    /// fire and retracts them. The host decides
    /// what alarms; the watch does not evaluate thresholds itself. A host forwards
    /// what its own mute lets through: Loop's mute silences every alert, so it
    /// forwards none while muted; a host whose critical alerts bypass its mute
    /// may forward those.
    public static let alerts = SmartwatchCapabilities(rawValue: 1 << 4)
    /// Boluses requested from the watch. The plugin must authenticate each
    /// request; the host then applies its own permission and safety checks.
    public static let remoteBolus = SmartwatchCapabilities(rawValue: 1 << 5)
    /// Therapy context: basal, insulin sensitivity, eventual glucose, sensitivity
    /// ratio, correction target and the active preset. Off unless a plugin declares it.
    public static let therapy = SmartwatchCapabilities(rawValue: 1 << 6)
    /// The watch can ask the host to mute its alerts. The host acts on it only if
    /// its user allowed muting from the watch.
    public static let remoteMute = SmartwatchCapabilities(rawValue: 1 << 7)
    /// The watch can ask the host to add a carb entry. The host acts on it only
    /// if its user allowed it.
    public static let remoteCarbs = SmartwatchCapabilities(rawValue: 1 << 8)
    /// The watch can ask the host to start or end an override preset. The host
    /// sends its presets and acts on requests only if its user allowed it.
    public static let remoteOverride = SmartwatchCapabilities(rawValue: 1 << 9)
    /// The watch can ask the host to start or end a temp target preset, for hosts
    /// that have temp targets. The host acts on it only if its user allowed it.
    public static let remoteTempTarget = SmartwatchCapabilities(rawValue: 1 << 10)
}

extension SmartwatchCapabilities: CustomStringConvertible {
    private static let names: [(SmartwatchCapabilities, String)] = [
        (.glucose, "glucose"),
        (.history, "history"),
        (.prediction, "prediction"),
        (.loopStatus, "loopStatus"),
        (.alerts, "alerts"),
        (.remoteBolus, "remoteBolus"),
        (.therapy, "therapy"),
        (.remoteMute, "remoteMute"),
        (.remoteCarbs, "remoteCarbs"),
        (.remoteOverride, "remoteOverride"),
        (.remoteTempTarget, "remoteTempTarget"),
    ]

    /// The capability names, for logs, for example "loopStatus, remoteBolus".
    /// Bits without a name show as their raw value.
    public var description: String {
        var parts = Self.names.filter { contains($0.0) }.map(\.1)
        let unnamed = subtracting(Self.names.reduce(into: []) { $0.formUnion($1.0) })
        if !unnamed.isEmpty {
            parts.append("raw value \(unnamed.rawValue)")
        }
        return parts.isEmpty ? "none" : parts.joined(separator: ", ")
    }
}

/// What the algorithm is working with right now, sent with `.therapy`. Glucose
/// values are mg/dL. A host leaves out what it doesn't have: Loop has no
/// sensitivity ratio, for example.
public struct SmartwatchTherapyContext: Equatable, Sendable {
    /// Units per hour of the running temp basal; `nil` while none is running.
    public var tempBasalRate: Double?

    /// Units per hour of the scheduled basal now.
    public var scheduledBasalRate: Double?

    /// mg/dL per unit, the insulin sensitivity now.
    public var insulinSensitivity: Double?

    /// mg/dL, where the latest forecast ends.
    public var eventualGlucose: Double?

    /// The algorithm's sensitivity ratio (1 = no adjustment), for hosts that have one.
    public var sensitivityRatio: Double?

    /// mg/dL, the correction range in effect now, including any preset or temp target.
    public var correctionRange: ClosedRange<Double>?

    /// The name of the active preset, override or temp target.
    public var activePresetName: String?

    /// When the active preset ends; `nil` while none is active or it runs indefinitely.
    public var activePresetEnd: Date?

    public init(
        tempBasalRate: Double? = nil,
        scheduledBasalRate: Double? = nil,
        insulinSensitivity: Double? = nil,
        eventualGlucose: Double? = nil,
        sensitivityRatio: Double? = nil,
        correctionRange: ClosedRange<Double>? = nil,
        activePresetName: String? = nil,
        activePresetEnd: Date? = nil
    ) {
        self.tempBasalRate = tempBasalRate
        self.scheduledBasalRate = scheduledBasalRate
        self.insulinSensitivity = insulinSensitivity
        self.eventualGlucose = eventualGlucose
        self.sensitivityRatio = sensitivityRatio
        self.correctionRange = correctionRange
        self.activePresetName = activePresetName
        self.activePresetEnd = activePresetEnd
    }
}

/// A glucose display unit. Plugins get plain values instead of a quantity type,
/// so they build against any LoopKit variant a host uses.
public enum SmartwatchGlucoseUnit: Equatable, Sendable {
    case milligramsPerDeciliter
    case millimolesPerLiter
}

/// A glucose trend, independent of LoopKit's `GlucoseTrend` so the wire model
/// carries no LoopKit type. Raw values match `GlucoseTrend` (1...7), so a host
/// maps with `SmartwatchGlucoseTrend(rawValue:)`.
public enum SmartwatchGlucoseTrend: Int, Equatable, Sendable, CaseIterable {
    case upUpUp = 1
    case upUp
    case up
    case flat
    case down
    case downDown
    case downDownDown
}

/// A stored glucose reading, in mg/dL.
public struct SmartwatchGlucoseReading: Equatable, Sendable {
    public var date: Date
    public var milligramsPerDeciliter: Double
    public var trend: SmartwatchGlucoseTrend?
    /// mg/dL per minute, if the CGM reports a rate.
    public var trendRate: Double?
    /// Entered by the user, such as a fingerstick.
    public var wasUserEntered: Bool
    /// Shown by the CGM but not to be used for dosing or graphs.
    public var isDisplayOnly: Bool

    public init(date: Date, milligramsPerDeciliter: Double, trend: SmartwatchGlucoseTrend? = nil, trendRate: Double? = nil, wasUserEntered: Bool = false, isDisplayOnly: Bool = false) {
        self.date = date
        self.milligramsPerDeciliter = milligramsPerDeciliter
        self.trend = trend
        self.trendRate = trendRate
        self.wasUserEntered = wasUserEntered
        self.isDisplayOnly = isDisplayOnly
    }
}

/// One point of the predicted glucose curve, in mg/dL.
public struct SmartwatchPredictedGlucose: Equatable, Sendable {
    public var date: Date
    public var milligramsPerDeciliter: Double

    public init(date: Date, milligramsPerDeciliter: Double) {
        self.date = date
        self.milligramsPerDeciliter = milligramsPerDeciliter
    }
}

/// The state a watch shows, built by the host.
///
/// The host sends a new snapshot as soon as a new CGM reading is stored, before
/// the loop runs, and again when the loop's output changes. Loop-derived values
/// keep their last known value until the loop updates them.
public struct SmartwatchStatusSnapshot: Equatable {
    /// How far back `glucoseHistory` reaches.
    public static let historyInterval: TimeInterval = .hours(3)

    public var displayUnit: SmartwatchGlucoseUnit

    /// Bolus context, with `.remoteBolus`. Replaced whenever the recommendation, the
    /// maximum bolus or the latest glucose changes, and after each watch bolus.
    public var bolusContext: SmartwatchBolusContext?

    /// The host's override presets, with `.remoteOverride`.
    public var overridePresets: [SmartwatchPreset]?

    /// The host's temp target presets, with `.remoteTempTarget`.
    public var tempTargetPresets: [SmartwatchPreset]?

    /// The latest stored reading, including user-entered and display-only
    /// readings; check their flags before showing one as a CGM reading.
    public var glucose: SmartwatchGlucoseReading?

    /// Stored readings from the last `historyInterval`, oldest first.
    /// Empty unless the plugin declares `.history`.
    public var glucoseHistory: [SmartwatchGlucoseReading]

    /// Predicted glucose from the last loop run. `nil` unless the plugin
    /// declares `.prediction`, or before the loop has run.
    public var predictedGlucose: [SmartwatchPredictedGlucose]?

    /// Units of insulin on board, with `.loopStatus`.
    public var insulinOnBoard: Double?

    /// Grams of carbs on board, with `.loopStatus`.
    public var carbsOnBoard: Double?

    /// When the loop last completed, with `.loopStatus`.
    public var lastLoopCompleted: Date?

    /// Whether automatic dosing is on, with `.loopStatus`. True only in full
    /// closed loop; hosts with other modes (open loop, low glucose suspend only,
    /// basal testing) send false for them.
    public var isClosedLoop: Bool?

    /// Basal, sensitivity and target context, with `.therapy`.
    public var therapy: SmartwatchTherapyContext?

    /// The remote actions the user allowed for this watch: a subset of the
    /// remote capabilities in `effectiveCapabilities`, so a watch can hide what
    /// is off. Informational only: the host checks its permissions on every request.
    public var permittedActions: SmartwatchCapabilities

    /// The host's largest carb entry in grams, with `.remoteCarbs`.
    public var maximumCarbEntry: Double?

    /// The pump's smallest bolus step in units, with `.remoteBolus`, for a watch
    /// that picks an amount before it has a bolus context.
    public var bolusIncrement: Double?

    /// The smallest step between a pump's supported bolus volumes, for `bolusIncrement`.
    public static func bolusIncrement(of supportedBolusVolumes: [Double]) -> Double? {
        let steps = zip(supportedBolusVolumes.dropFirst(), supportedBolusVolumes).map { $0 - $1 }.filter { $0 > 0 }
        return steps.min() ?? supportedBolusVolumes.first
    }

    public init(
        displayUnit: SmartwatchGlucoseUnit,
        glucose: SmartwatchGlucoseReading?,
        glucoseHistory: [SmartwatchGlucoseReading] = [],
        predictedGlucose: [SmartwatchPredictedGlucose]? = nil,
        insulinOnBoard: Double? = nil,
        carbsOnBoard: Double? = nil,
        lastLoopCompleted: Date? = nil,
        isClosedLoop: Bool? = nil,
        bolusContext: SmartwatchBolusContext? = nil,
        therapy: SmartwatchTherapyContext? = nil,
        overridePresets: [SmartwatchPreset]? = nil,
        tempTargetPresets: [SmartwatchPreset]? = nil,
        permittedActions: SmartwatchCapabilities = [],
        maximumCarbEntry: Double? = nil,
        bolusIncrement: Double? = nil
    ) {
        self.displayUnit = displayUnit
        self.glucose = glucose
        self.glucoseHistory = glucoseHistory
        self.predictedGlucose = predictedGlucose
        self.insulinOnBoard = insulinOnBoard
        self.carbsOnBoard = carbsOnBoard
        self.lastLoopCompleted = lastLoopCompleted
        self.isClosedLoop = isClosedLoop
        self.bolusContext = bolusContext
        self.therapy = therapy
        self.overridePresets = overridePresets
        self.tempTargetPresets = tempTargetPresets
        self.permittedActions = permittedActions
        self.maximumCarbEntry = maximumCarbEntry
        self.bolusIncrement = bolusIncrement
    }
}

/// Identifies a host alert so it can be retracted.
public struct SmartwatchAlertIdentifier: Equatable, Hashable, Sendable {
    public var value: String
    public init(_ value: String) {
        self.value = value
    }
}

/// How urgent a host alert is. Maps from the host's own interruption levels.
public enum SmartwatchAlertLevel: Int, Equatable, Sendable {
    case informational
    case warning
    case critical
}

/// Which glucose alert a host alert is. The host sets it on `SmartwatchAlert`;
/// `nil` means the alert isn't a glucose alert.
///
/// Why a dedicated type rather than reading the alert itself:
/// - A watch needs to know *which* glucose alert is active, for example to colour
///   its glucose ring red for a low and amber for a high, without thresholds of
///   its own (they would drift from the host's alert settings).
/// - The alert identifier can't tell it reliably: every host names its alerts
///   differently. Loop uses `GlucoseAlertManager.glucose.low`, Trio
///   `Trio.glucose.low.<UUID>` and calls its predicted low `forecastedLow`. A
///   plugin matching such strings works with one host and silently does nothing
///   with another.
/// - The interruption level can't either: low and high are both time-sensitive,
///   and urgent low is critical only in builds with the critical-alerts
///   entitlement.
/// - Pump, CGM and other alerts must not change a glucose display, so they are
///   `nil` rather than guessed from their text.
///
/// So the host, which knows its own alerts, maps them once to these cases.
public enum SmartwatchGlucoseAlertType: String, Equatable, Sendable {
    case urgentLow
    case low
    case high
    /// A low the host forecasts, before glucose is low.
    case predictedLow
}

/// An alert the host issued and forwarded to the watch. The host evaluates its
/// own alerts (on a background CGM or pump update) and sends the result; the
/// watch shows it and vibrates.
public struct SmartwatchAlert: Equatable, Sendable {
    public var identifier: SmartwatchAlertIdentifier
    public var level: SmartwatchAlertLevel
    public var title: String?
    public var body: String?
    /// When the host issued the alert.
    public var issuedAt: Date
    /// Set by the host for glucose alerts; `nil` for any other alert.
    public var glucoseAlertType: SmartwatchGlucoseAlertType?

    public init(identifier: SmartwatchAlertIdentifier, level: SmartwatchAlertLevel, title: String? = nil, body: String? = nil, issuedAt: Date, glucoseAlertType: SmartwatchGlucoseAlertType? = nil) {
        self.identifier = identifier
        self.level = level
        self.title = title
        self.body = body
        self.issuedAt = issuedAt
        self.glucoseAlertType = glucoseAlertType
    }
}

/// An alert about the watch itself, such as a missing companion app, which the
/// plugin asks the host to show (`issueDeviceAlert`). Glucose alerts come from
/// the host, never from a plugin.
public struct SmartwatchDeviceAlert: Equatable, Sendable {
    /// Unique within the plugin; issuing the same identifier again replaces the alert.
    public var identifier: SmartwatchAlertIdentifier
    public var level: SmartwatchAlertLevel
    public var title: String
    public var body: String

    public init(identifier: SmartwatchAlertIdentifier, level: SmartwatchAlertLevel, title: String, body: String) {
        self.identifier = identifier
        self.level = level
        self.title = title
        self.body = body
    }
}

/// One line for the host's device log, sent by the plugin. Mirrors LoopKit's
/// `DeviceLogEntryType` so a host that keeps a device log maps it directly,
/// without the plugin depending on `DeviceManagerDelegate`.
public struct SmartwatchDeviceLogEntry: Equatable, Sendable {
    public enum EntryType: String, Sendable {
        case send, receive, error, delegate, delegateResponse, connection
    }
    public var type: EntryType
    public var message: String
    /// The watch the line is about (for example the watchface UUID), if any.
    public var deviceIdentifier: String?

    public init(type: EntryType, message: String, deviceIdentifier: String? = nil) {
        self.type = type
        self.message = message
        self.deviceIdentifier = deviceIdentifier
    }
}

/// The host side of a watch plugin: what the plugin calls on the host.
///
/// **Who implements it:** the host app (Loop's `DeviceDataManager`, Trio's
/// `SmartwatchHost`). The host sets itself as `smartwatchManagerDelegate` right
/// after it creates or restores the manager, before the first snapshot.
///
/// **Threads:** a plugin may call any of these from any thread or task; the host
/// hops to its own actor. The `async` methods may suspend for as long as the host
/// needs (a bolus waits for the pump), so don't call them while holding a lock.
///
/// **What's optional:** a host must implement the first four. Device alerts
/// default to being ignored, and every remote action defaults to throwing
/// `.notAllowed`, so a host implements only what it supports.
public protocol SmartwatchManagerDelegate: AnyObject {
    /// The manager's `rawState` changed and should be saved.
    ///
    /// **Call it** after every change to what `rawState` returns: a setting the
    /// user changed in the plugin's screens, a newly paired watch, a new key. The
    /// host reads `rawState` and stores it at once, so the change survives a
    /// restart. Don't call it for state that isn't saved, such as counters.
    func smartwatchManagerDidUpdateState(_ manager: SmartwatchManager)

    /// Asks the host to remove the manager.
    ///
    /// **Call it** (through `notifyDelegateOfDeletion`) when the user deletes the
    /// watch in the plugin's settings, after the plugin has stopped its own work.
    /// The host then drops the manager and its saved state, and turns off the
    /// user's watch permissions, so a later watch starts with every remote action
    /// off. The host calls nothing on the manager afterwards.
    func smartwatchManagerWantsDeletion(_ manager: SmartwatchManager) async

    /// Asks the host to send the current snapshot again.
    ///
    /// **Call it** when the plugin needs fresh data rather than waiting for the
    /// next reading: the watch reconnected or restarted, the user changed
    /// `requestedCapabilities`, or the plugin added carbs and needs a bolus
    /// context that counts them. The host answers with `watchDataDidUpdate`
    /// soon, not necessarily before this returns.
    func smartwatchManagerRequestsRefresh(_ manager: SmartwatchManager)

    /// A line for the host's device log.
    ///
    /// **Call it** for what someone reading a support log (Loop's Issue Report)
    /// needs: connections and disconnections, messages to and from the watch,
    /// each remote request and its outcome, and every error with its reason.
    /// Never log secrets such as keys or tokens. A host without a device log may
    /// ignore it.
    func smartwatchManager(_ manager: SmartwatchManager, didLogEvent event: SmartwatchDeviceLogEntry)

    /// Asks the host to show an alert about the watch itself, as one of the host's
    /// own alerts from this plugin.
    ///
    /// **Call it** when the watch can't work until the user does something outside
    /// the watch, for example a companion app the plugin needs is missing (the
    /// Garmin plugin when Garmin Connect isn't installed) or a permission was
    /// withdrawn. Issue it once per problem, with a stable identifier; issuing the
    /// same identifier again replaces it. Call `retractDeviceAlert` once the
    /// problem is fixed.
    ///
    /// **Don't use it** for glucose alerts (the host issues those, and forwards
    /// them with `watchAlertDidIssue`), or for a dropped connection that recovers
    /// on its own: log that instead.
    ///
    /// The host decides how to show it and may lower its level; no plugin alert is
    /// critical. A host may also ignore it (the default), so the plugin should show
    /// the same problem in its own settings.
    func smartwatchManager(_ manager: SmartwatchManager, issueDeviceAlert alert: SmartwatchDeviceAlert)

    /// Withdraws an alert the plugin issued with `issueDeviceAlert`.
    ///
    /// **Call it** as soon as the cause is gone (the companion app is installed,
    /// the permission granted), and when the watch is deleted.
    func smartwatchManager(_ manager: SmartwatchManager, retractDeviceAlert identifier: SmartwatchAlertIdentifier)

    /// Asks the host to deliver a bolus the user confirmed on the watch.
    ///
    /// **Call it** only with `.remoteBolus` in `effectiveCapabilities`, only for a
    /// request the user confirmed on the watch and the plugin authenticated (for
    /// example signed by the watch), and once per request: a resend of a request
    /// already passed on must not reach the host again. Use the token from the
    /// latest snapshot's `bolusContext`, and `requestedAt` from the watch.
    ///
    /// The host checks its user's permission, the request's age, the context
    /// token, recent glucose, the maximum bolus, the recommendation (unless
    /// forced) and its rate limits, all within `remoteActionLimits`, plus checks of
    /// its own, and then delivers. Don't retry a refusal automatically.
    ///
    /// - Returns: The delivered units, rounded to a supported volume.
    /// - Throws: `SmartwatchBolusError`; `.inProgress` when the same context's
    ///   bolus is still being delivered, so the watch doesn't report a failure.
    func smartwatchManager(_ manager: SmartwatchManager, requestBolus request: SmartwatchBolusRequest) async throws -> Double

    /// Asks the host to mute its alerts, as the user chose on the watch.
    ///
    /// **Call it** only with `.remoteMute` in `effectiveCapabilities`, for a mute
    /// the user confirmed on the watch, with `requestedAt` from the watch. The
    /// host checks its user's permission and the request's age, and may cap the
    /// duration at its own maximum.
    ///
    /// - Returns: When the mute ends.
    /// - Throws: `SmartwatchAlertMuteError`.
    func smartwatchManager(_ manager: SmartwatchManager, requestAlertMute request: SmartwatchAlertMuteRequest) async throws -> Date

    /// Asks the host to add carbs, as the user chose on the watch.
    ///
    /// **Call it** only with `.remoteCarbs` in `effectiveCapabilities`, once per
    /// request, with `requestedAt` from the watch; the entry is dated then. The
    /// host checks its user's permission, the request's age, its maximum carb
    /// entry and its rate limit. For a meal bolus, add the carbs first, then ask
    /// for a refresh and bolus against the new context.
    ///
    /// - Returns: The grams added.
    /// - Throws: `SmartwatchCarbEntryError`.
    func smartwatchManager(_ manager: SmartwatchManager, requestCarbEntry request: SmartwatchCarbEntryRequest) async throws -> Double

    /// Asks the host to start an override preset, or end the running one.
    ///
    /// **Call it** only with `.remoteOverride` in `effectiveCapabilities`, with a
    /// preset id from the latest snapshot's `overridePresets` and `requestedAt`
    /// from the watch. The host checks its user's permission, the request's age
    /// and that the preset exists. Ending when none is running succeeds.
    ///
    /// - Throws: `SmartwatchPresetError`.
    func smartwatchManager(_ manager: SmartwatchManager, requestOverride request: SmartwatchOverrideRequest) async throws

    /// Asks the host to start a temp target preset, or end the running one.
    ///
    /// **Call it** only with `.remoteTempTarget` in `effectiveCapabilities`, with a
    /// preset id from the latest snapshot's `tempTargetPresets`; otherwise as
    /// `requestOverride`. Hosts without temp targets (Loop) refuse it.
    ///
    /// - Throws: `SmartwatchPresetError`.
    func smartwatchManager(_ manager: SmartwatchManager, requestTempTarget request: SmartwatchTempTargetRequest) async throws
}

/// Device alerts are ignored unless the host shows them, so a plugin should also
/// show the problem in its own settings.
public extension SmartwatchManagerDelegate {
    func smartwatchManager(_ manager: SmartwatchManager, issueDeviceAlert alert: SmartwatchDeviceAlert) {}
    func smartwatchManager(_ manager: SmartwatchManager, retractDeviceAlert identifier: SmartwatchAlertIdentifier) {}
}

/// Every remote action is refused unless the host implements it.
public extension SmartwatchManagerDelegate {
    func smartwatchManager(_ manager: SmartwatchManager, requestBolus request: SmartwatchBolusRequest) async throws -> Double {
        throw SmartwatchBolusError.notAllowed
    }

    func smartwatchManager(_ manager: SmartwatchManager, requestAlertMute request: SmartwatchAlertMuteRequest) async throws -> Date {
        throw SmartwatchAlertMuteError.notAllowed
    }

    func smartwatchManager(_ manager: SmartwatchManager, requestCarbEntry request: SmartwatchCarbEntryRequest) async throws -> Double {
        throw SmartwatchCarbEntryError.notAllowed
    }

    func smartwatchManager(_ manager: SmartwatchManager, requestOverride request: SmartwatchOverrideRequest) async throws {
        throw SmartwatchPresetError.notAllowed
    }

    func smartwatchManager(_ manager: SmartwatchManager, requestTempTarget request: SmartwatchTempTargetRequest) async throws {
        throw SmartwatchPresetError.notAllowed
    }
}

/// A watch that shows the host app's state, implemented by a plugin.
///
/// **Lifecycle:**
/// 1. *New:* the plugin's setup UI creates the manager; *after a restart:* the
///    host calls `init?(rawState:)` with the saved state.
/// 2. The host sets `smartwatchManagerDelegate`, then sends the first snapshot.
/// 3. From then on the host calls `watchDataDidUpdate` for new data and, with
///    `.alerts`, the alert methods; the plugin calls the delegate.
/// 4. When the user deletes the watch, the plugin stops its work and calls
///    `notifyDelegateOfDeletion`; the host drops it.
///
/// **Threads:** the host calls the `@MainActor` methods on the main actor and
/// expects them to return quickly: send to the watch asynchronously. The plugin
/// may call the delegate from any thread.
///
/// **Capabilities:** the host fills a snapshot, forwards alerts and passes remote
/// actions only for `effectiveCapabilities`, what the plugin both declares and
/// requests.
public protocol SmartwatchManager: AnyObject {
    typealias RawStateValue = [String: Any]

    /// Recreates the manager from its saved state when the host starts.
    ///
    /// Return `nil` only if the state can't be restored; the host then keeps the
    /// state for a later build. Don't call the delegate here: it isn't set yet.
    init?(rawState: RawStateValue)

    /// The state the host saves, to recreate the manager on the next launch.
    ///
    /// Read by the host after `smartwatchManagerDidUpdateState` and when it saves.
    /// Use property-list values only (strings, numbers, dates, data, arrays and
    /// dictionaries of them); encode anything else as `Data`. Keep secrets out,
    /// or keep them only as long as the host's storage is acceptable for them.
    var rawState: RawStateValue { get }

    /// A stable identifier for this watch manager, used to save, restore and log
    /// it. Never change it: saved state is matched by it. It matches the plugin
    /// bundle's `com.loopkit.Loop.SmartwatchManagerIdentifier`, and, when the
    /// manager also conforms to `Pluggable` (via a host's `DeviceManager`), the
    /// same value satisfies both.
    var pluginIdentifier: String { get }

    /// The host, set by the host after creating or restoring the manager and
    /// before the first snapshot. Keep it `weak`.
    var smartwatchManagerDelegate: SmartwatchManagerDelegate? { get set }

    /// Everything the plugin can show or do. The host never gives it more.
    ///
    /// Declare a remote action only when the watch side confirms each request with
    /// the user and the plugin can authenticate it; hosts still require their
    /// user's permission for each one.
    static var capabilities: SmartwatchCapabilities { get }

    /// What the watch wants right now, for example less than `capabilities` when
    /// the user turned a display element off, so the host doesn't fetch it. Only
    /// declared capabilities count: anything requested beyond `capabilities` is
    /// ignored (see `effectiveCapabilities`). Call `smartwatchManagerRequestsRefresh`
    /// after it changes. Defaults to `capabilities`.
    var requestedCapabilities: SmartwatchCapabilities { get }

    /// The limits the host applies to this watch's remote actions. Defaults to
    /// `.standard`. A plugin may declare its own, for example to match its watch
    /// app's rules; the host applies them as given, together with its own checks
    /// (such as Trio's max IOB).
    var remoteActionLimits: SmartwatchRemoteActionLimits { get }

    /// The latest snapshot of the host's state.
    ///
    /// **Called** on the main actor as soon as a new glucose reading is stored,
    /// whenever the loop's output changes, after the plugin asks for a refresh,
    /// and when the user's watch permissions change. A host may skip a snapshot
    /// equal to the last one. It carries only what `effectiveCapabilities` allows.
    /// Keep it for later (a reconnecting watch needs the latest), and send to the
    /// watch without blocking.
    @MainActor
    func watchDataDidUpdate(_ snapshot: SmartwatchStatusSnapshot)

    /// A host alert fired and should show on the watch.
    ///
    /// **Called** on the main actor, only with `.alerts`, each time the host issues
    /// or repeats an alert it forwards to watches (Loop and Trio forward their
    /// glucose alerts and follow their own mute). Use
    /// `glucoseAlertType` rather than the identifier to tell which glucose alert
    /// it is.
    @MainActor
    func watchAlertDidIssue(_ alert: SmartwatchAlert)

    /// A host alert was retracted and should clear on the watch.
    ///
    /// **Called** on the main actor, only with `.alerts`, when the host retracts
    /// an alert it forwarded, for example when glucose is back in range.
    @MainActor
    func watchAlertDidRetract(_ identifier: SmartwatchAlertIdentifier)

    /// A note from the host about the watch, such as why an alert was not sent to
    /// it or when the host repeats one.
    ///
    /// **Called** on the main actor. The host has already written it to its own
    /// device log; the plugin may show it in its own log next to the watch traffic.
    @MainActor
    func watchHostDidLog(_ message: String)

    /// A URL the host doesn't handle itself, such as a companion app's callback
    /// after the user picked a watch there (Garmin Connect's `device-select-resp`).
    ///
    /// **Called** on the main actor for every such URL; return `true` only if the
    /// plugin handled it. The host registers the URL scheme. Defaults to `false`.
    @MainActor
    func watchHostDidReceiveURL(_ url: URL) -> Bool

    /// Stops the manager and asks the host to remove it.
    ///
    /// **Called** when the user deletes the watch, usually from the plugin's own
    /// settings. Stop everything (Bluetooth, timers, sending), retract device
    /// alerts, then call `notifyDelegateOfDeletion(completion:)`. The default does
    /// only the last step.
    func delete(completion: @escaping () -> Void)
}

public extension SmartwatchManager {
    var requestedCapabilities: SmartwatchCapabilities { Self.capabilities }
    var remoteActionLimits: SmartwatchRemoteActionLimits { .standard }

    /// What the host acts on: the requested capabilities the plugin declares.
    /// Hosts use this for every capability check (snapshot contents, alerts and
    /// remote actions), so a plugin can't obtain a capability it didn't declare.
    /// Not a protocol requirement, so a plugin can't override it.
    var effectiveCapabilities: SmartwatchCapabilities {
        Self.capabilities.intersection(requestedCapabilities)
    }

    /// Requested capabilities the plugin doesn't declare; ignored by hosts.
    var undeclaredRequestedCapabilities: SmartwatchCapabilities {
        requestedCapabilities.subtracting(Self.capabilities)
    }

    // Alerts are capability-gated; a plugin without `.alerts` need not implement these.
    @MainActor
    func watchAlertDidIssue(_ alert: SmartwatchAlert) {}
    @MainActor
    func watchAlertDidRetract(_ identifier: SmartwatchAlertIdentifier) {}
    @MainActor
    func watchHostDidLog(_ message: String) {}
    @MainActor
    func watchHostDidReceiveURL(_ url: URL) -> Bool { false }

    /// Asks the delegate to remove the manager, then calls `completion`.
    func notifyDelegateOfDeletion(completion: @escaping () -> Void) {
        Task {
            await smartwatchManagerDelegate?.smartwatchManagerWantsDeletion(self)
            completion()
        }
    }

    /// Override this default behaviour if the watch manager needs to complete tasks before being deleted
    func delete(completion: @escaping () -> Void) {
        notifyDelegateOfDeletion(completion: completion)
    }
}
