//
//  SmartwatchManager.swift
//  LoopKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation

/// What changed in the host since a plugin last read it, sent with
/// `SmartwatchManager.hostDataDidChange`. A plugin reads only what it shows.
public struct SmartwatchHostDataChange: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// A new glucose reading was stored, before the loop runs on it.
    public static let glucose = SmartwatchHostDataChange(rawValue: 1 << 0)
    /// The loop completed, or its output changed: `SmartwatchLoopState`, temp basal.
    public static let loop = SmartwatchHostDataChange(rawValue: 1 << 1)
    /// Override or temp target presets, or the active one, changed.
    public static let presets = SmartwatchHostDataChange(rawValue: 1 << 2)
    /// A setting a watch may show or check changed: display unit, glucose display
    /// limits, maximum bolus or carb entry, schedules, the pump's bolus volumes.
    public static let settings = SmartwatchHostDataChange(rawValue: 1 << 3)
    /// The host's alert mute started, changed or ended.
    public static let alertMute = SmartwatchHostDataChange(rawValue: 1 << 4)

    public static let all: SmartwatchHostDataChange = [.glucose, .loop, .presets, .settings, .alertMute]
}

/// The loop's output from one loop run, read together so a watch never shows a
/// new value next to an older one from a previous run.
public struct SmartwatchLoopState {
    /// When the loop last completed; `nil` before the first run.
    public var lastLoopCompleted: Date?

    /// Whether automatic dosing is on. True only in full closed loop; hosts with
    /// other modes (open loop, low glucose suspend only) report false for them.
    public var isClosedLoop: Bool

    public var insulinOnBoard: InsulinValue?

    public var carbsOnBoard: CarbValue?

    /// The forecasts from the last loop run, one curve per forecast the host's
    /// algorithm makes: Loop has one, Trio up to four (oref's IOB, ZT, COB and UAM,
    /// as many as it computed). Each curve is a normal forecast, one value per
    /// time, ascending, reaching at most `forecastHorizon` past its first value.
    /// A watch draws a cone as the per-time minimum and maximum across the curves
    /// (cut where the shortest ends; one curve gives its line), or the curves as
    /// lines. Empty before the loop has run.
    ///
    /// Curves, not one flat array: a flat array is one forecast, with one value per
    /// time and the eventual glucose last. Several curves mixed into it would lose
    /// which value belongs to which curve and would zigzag when drawn as a line.
    public var predictedGlucose: [[PredictedGlucoseValue]]

    /// How far `predictedGlucose` reaches past each curve's first value. Hosts cut
    /// their curves there, so every plugin gets the same span from either host.
    public static let forecastHorizon: TimeInterval = 4 * 60 * 60

    /// Where the algorithm expects glucose to end up. Loop reports the end of its
    /// whole forecast, not cut at `forecastHorizon`; a host whose algorithm
    /// computes its own (Trio's eventual BG) reports that.
    public var eventualGlucose: LoopQuantity?

    /// The algorithm's sensitivity ratio (1 = no adjustment), for hosts that have one.
    public var sensitivityRatio: Double?

    public init(
        lastLoopCompleted: Date?,
        isClosedLoop: Bool,
        insulinOnBoard: InsulinValue? = nil,
        carbsOnBoard: CarbValue? = nil,
        predictedGlucose: [[PredictedGlucoseValue]] = [],
        eventualGlucose: LoopQuantity? = nil,
        sensitivityRatio: Double? = nil
    ) {
        self.lastLoopCompleted = lastLoopCompleted
        self.isClosedLoop = isClosedLoop
        self.insulinOnBoard = insulinOnBoard
        self.carbsOnBoard = carbsOnBoard
        self.predictedGlucose = predictedGlucose
        self.eventualGlucose = eventualGlucose
        self.sensitivityRatio = sensitivityRatio
    }
}

/// The low and high glucose limits a host shows glucose against, for a watch's
/// colours and its low and high graph lines. For display only, never for alarms:
/// see `SmartwatchManagerDelegate.smartwatchManagerGlucoseDisplayLimits`.
public struct SmartwatchGlucoseDisplayLimits: Equatable, Sendable {
    public let low: LoopQuantity
    public let high: LoopQuantity

    /// `nil` unless `low` is below `high`.
    public init?(low: LoopQuantity, high: LoopQuantity) {
        guard low < high else {
            return nil
        }
        self.low = low
        self.high = high
    }
}

/// Which glucose alert a host alert is. The host passes it with each alert it
/// forwards (`watchAlertDidIssue`); `nil` means the alert isn't a glucose alert.
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

/// The host side of a watch plugin: what the plugin reads from and asks of the host.
///
/// **Who implements it:** the host app, in an object of its own for the watch
/// (Loop's `SmartwatchManagerHost`, Trio's `SmartwatchHost`), so it knows which
/// manager an alert came from. The host sets it as `smartwatchManagerDelegate`
/// right after it creates or restores the manager, then calls
/// `hostDataDidChange(.all)`.
///
/// **Logs and alerts** come from `DeviceManagerDelegate`, as for CGM and pump
/// plugins: `deviceManager(_:logEventForDeviceIdentifier:type:message:completion:)`
/// and `issueAlert`/`retractAlert`. Use alerts for problems with the watch itself
/// that the user must fix outside it, such as a missing companion app; never for
/// glucose (the host forwards its own glucose alerts). A host shows a watch
/// plugin's alerts at most time-sensitive, never critical.
///
/// **Reads** return what the host has now. Read after `hostDataDidChange`, and
/// read only what the watch shows. They may suspend while the host fetches from
/// its stores.
///
/// **Actions** (bolus, carbs, presets, mute) get the same checks the host applies
/// to any request of that kind, such as its maximum bolus, and nothing
/// watch-specific. Whether a watch may ask at all, and how fresh or frequent its
/// requests must be, is the plugin's own setting and policy
/// (`SmartwatchRemoteActionPolicy.swift` has shared checks). A host that doesn't
/// offer an action throws `.notAllowed` (the default).
///
/// **Threads:** like every `DeviceManagerDelegate` (through `PersistedAlertStore`),
/// the delegate is main-actor isolated: call its synchronous methods on the main
/// actor; the `async` ones may be awaited from any task. Don't await them while
/// holding a lock: a bolus waits for the pump.
public protocol SmartwatchManagerDelegate: DeviceManagerDelegate {
    /// The manager's `rawState` changed and should be saved.
    ///
    /// **Call it** after every change to what `rawState` returns: a setting the
    /// user changed in the plugin's screens, a newly paired watch, a new key. The
    /// host reads `rawState` and stores it at once, so the change survives a
    /// restart. Don't call it for state that isn't saved, such as counters.
    func smartwatchManagerDidUpdateState(_ manager: SmartwatchManager)

    /// Asks the host to remove the manager.
    ///
    /// **Call it** from `delete()` when the user deletes the watch in the plugin's
    /// settings, after the plugin has stopped its own work and retracted its
    /// alerts. The host then drops the manager and its saved state, and calls
    /// nothing on it afterwards.
    func smartwatchManagerWantsDeletion(_ manager: SmartwatchManager) async

    // MARK: Reads

    /// The unit the user sees glucose in.
    func smartwatchManagerGlucoseDisplayUnit(_ manager: SmartwatchManager) async -> LoopUnit

    /// Stored glucose readings since `date`, oldest first, including user-entered
    /// and display-only readings: check their flags before showing one as a CGM reading.
    func smartwatchManager(_ manager: SmartwatchManager, glucoseSamplesSince date: Date) async throws -> [StoredGlucoseSample]

    /// The loop's output from its last run.
    func smartwatchManagerLoopState(_ manager: SmartwatchManager) async -> SmartwatchLoopState

    /// The scheduled basal rate now, in units per hour.
    func smartwatchManagerScheduledBasalRate(_ manager: SmartwatchManager) async -> LoopQuantity?

    /// The temp basal running now; `nil` while none is.
    func smartwatchManagerTempBasal(_ manager: SmartwatchManager) async -> DoseEntry?

    /// The insulin sensitivity now, including any active override.
    func smartwatchManagerInsulinSensitivity(_ manager: SmartwatchManager) async -> LoopQuantity?

    /// The correction range in effect now, including any override or temp target.
    func smartwatchManagerCorrectionRange(_ manager: SmartwatchManager) async -> ClosedRange<LoopQuantity>?

    /// The low and high glucose limits the host shows glucose against, for a
    /// watch's colours and its low and high graph lines. `nil` (the default) when
    /// the host has none. Changes come with `.settings`.
    ///
    /// **For display only, never for alarms.** A plugin must not compare glucose
    /// with these limits to buzz, sound, show or clear a glucose alarm. The host
    /// decides when glucose is low or high, with its own delays, snoozes, mute,
    /// schedules and forecasts, and tells the plugin through `watchAlertDidIssue`
    /// and `watchAlertDidRetract`. A watch deciding by itself would alarm when the
    /// host doesn't, or stay quiet when it does.
    ///
    /// Loop returns the low and high of its active glucose alert profile; Trio the
    /// low and high its statistics and home screen use.
    func smartwatchManagerGlucoseDisplayLimits(_ manager: SmartwatchManager) async -> SmartwatchGlucoseDisplayLimits?

    /// The user's override presets (Loop's presets, Trio's overrides).
    func smartwatchManagerOverridePresets(_ manager: SmartwatchManager) async -> [TemporaryPreset]

    /// The override running now; `nil` while none is. One started from a preset
    /// has the context `.preset(preset)`, so a watch can mark that preset as running.
    func smartwatchManagerActiveOverride(_ manager: SmartwatchManager) async -> TemporaryScheduleOverride?

    /// The user's temp target presets, for hosts that have temp targets (Trio):
    /// presets whose settings set only a target range. `nil` (the default) for a
    /// host without temp targets; empty for one whose user has no presets.
    func smartwatchManagerTempTargetPresets(_ manager: SmartwatchManager) async -> [TemporaryPreset]?

    /// The temp target running now; `nil` while none is, or for hosts without temp
    /// targets. One started from a preset has the context `.preset(preset)`.
    func smartwatchManagerActiveTempTarget(_ manager: SmartwatchManager) async -> TemporaryScheduleOverride?

    /// When the host's alert mute ends; `nil` while alerts aren't muted.
    func smartwatchManagerAlertMuteEnd(_ manager: SmartwatchManager) async -> Date?

    /// The user's maximum bolus, in units.
    func smartwatchManagerMaximumBolus(_ manager: SmartwatchManager) async -> Double?

    /// The host's largest carb entry, in grams.
    func smartwatchManagerMaximumCarbEntry(_ manager: SmartwatchManager) async -> Double?

    /// The bolus volumes the pump can deliver, in units; empty without a pump.
    func smartwatchManagerSupportedBolusVolumes(_ manager: SmartwatchManager) async -> [Double]

    /// The host's fast, medium and slow carb absorption times, for a watch that
    /// lets the user pick one. `nil` (the default) for a host whose carb model has
    /// no per-entry absorption time (Trio): a watch then shouldn't ask for one.
    func smartwatchManagerDefaultCarbAbsorptionTimes(_ manager: SmartwatchManager) async -> (fast: TimeInterval, medium: TimeInterval, slow: TimeInterval)?

    /// What the host would recommend now, with `grams` of carbs added (0 for none).
    /// Nothing is added or delivered.
    ///
    /// - Returns: Units, rounded to a supported volume; 0 when the host recommends none.
    /// - Throws: `SmartwatchBolusError`: `.invalidAmount` for carbs that aren't a
    ///   valid entry, `.refusedByHost` when no recommendation can be computed.
    func smartwatchManager(_ manager: SmartwatchManager, recommendBolusForCarbs grams: Double, absorptionTime: TimeInterval?) async throws -> Double

    // MARK: Actions

    /// Delivers a bolus.
    ///
    /// **Call it** once per bolus the user confirmed on the watch and the plugin's
    /// own checks passed. The host applies its own limits (Loop: maximum bolus;
    /// Trio: maximum bolus and maximum IOB), rounds to a supported volume and
    /// delivers. Only the host's current watch manager may bolus.
    ///
    /// - Returns: The units, once the pump accepted the bolus. It may still be
    ///   cancelled on the phone or the pump while it runs, and then delivers
    ///   less; the host doesn't report that to the plugin.
    /// - Throws: `SmartwatchBolusError`. `.deliveryFailed` when the pump was asked
    ///   and didn't accept it, including uncertain delivery. Every other error
    ///   means nothing was sent to the pump: `.exceedsMaximumBolus` or
    ///   `.refusedByHost` for the host's limits, `.inProgress` while another
    ///   bolus is being delivered.
    func smartwatchManager(_ manager: SmartwatchManager, deliverBolus units: Double) async throws -> Double

    /// Adds a carb entry dated `date`.
    ///
    /// **Call it** once per entry the user confirmed on the watch. The host
    /// applies its own maximum carb entry. For a meal bolus, add the carbs first,
    /// then ask for the recommendation again.
    ///
    /// - Parameter absorptionTime: `nil` for the host's default.
    /// - Returns: The grams added.
    /// - Throws: `SmartwatchCarbEntryError`.
    func smartwatchManager(_ manager: SmartwatchManager, addCarbEntry grams: Double, absorptionTime: TimeInterval?, date: Date) async throws -> Double

    /// Starts an override preset (by `TemporaryPreset.id`) or ends the running one.
    /// Ending when none is running succeeds.
    ///
    /// - Throws: `SmartwatchPresetError`.
    func smartwatchManager(_ manager: SmartwatchManager, enactOverride action: SmartwatchPresetAction) async throws

    /// Starts a temp target preset or ends the running one, for hosts that have
    /// temp targets. Others throw `.notAllowed` (the default).
    ///
    /// - Throws: `SmartwatchPresetError`.
    func smartwatchManager(_ manager: SmartwatchManager, enactTempTarget action: SmartwatchPresetAction) async throws

    /// Mutes the host's alerts for `duration`, or ends the mute when it's 0. The
    /// host may round the duration up to one it offers or cap it at its maximum.
    ///
    /// - Returns: When the mute ends (now, when it was ended).
    /// - Throws: `SmartwatchAlertMuteError`.
    func smartwatchManager(_ manager: SmartwatchManager, muteAlertsFor duration: TimeInterval) async throws -> Date
}

/// Reads a host may not have.
public extension SmartwatchManagerDelegate {
    func smartwatchManagerTempTargetPresets(_ manager: SmartwatchManager) async -> [TemporaryPreset]? { nil }
    func smartwatchManagerActiveTempTarget(_ manager: SmartwatchManager) async -> TemporaryScheduleOverride? { nil }
    func smartwatchManagerGlucoseDisplayLimits(_ manager: SmartwatchManager) async -> SmartwatchGlucoseDisplayLimits? { nil }
    func smartwatchManagerDefaultCarbAbsorptionTimes(_ manager: SmartwatchManager) async -> (fast: TimeInterval, medium: TimeInterval, slow: TimeInterval)? { nil }
}

/// Every action is refused unless the host implements it.
public extension SmartwatchManagerDelegate {
    func smartwatchManager(_ manager: SmartwatchManager, recommendBolusForCarbs grams: Double, absorptionTime: TimeInterval?) async throws -> Double {
        throw SmartwatchBolusError.notAllowed
    }

    func smartwatchManager(_ manager: SmartwatchManager, deliverBolus units: Double) async throws -> Double {
        throw SmartwatchBolusError.notAllowed
    }

    func smartwatchManager(_ manager: SmartwatchManager, addCarbEntry grams: Double, absorptionTime: TimeInterval?, date: Date) async throws -> Double {
        throw SmartwatchCarbEntryError.notAllowed
    }

    func smartwatchManager(_ manager: SmartwatchManager, enactOverride action: SmartwatchPresetAction) async throws {
        throw SmartwatchPresetError.notAllowed
    }

    func smartwatchManager(_ manager: SmartwatchManager, enactTempTarget action: SmartwatchPresetAction) async throws {
        throw SmartwatchPresetError.notAllowed
    }

    func smartwatchManager(_ manager: SmartwatchManager, muteAlertsFor duration: TimeInterval) async throws -> Date {
        throw SmartwatchAlertMuteError.notAllowed
    }
}

/// A watch that shows the host app's state, implemented by a plugin. A device
/// manager like a CGM or pump manager: `init?(rawState:)`, `rawState`,
/// `pluginIdentifier`, alert acknowledgement and sounds come from `DeviceManager`.
///
/// **Lifecycle:**
/// 1. *New:* the plugin's setup UI creates the manager; *after a restart:* the
///    host calls `init?(rawState:)` with the saved state.
/// 2. The host sets `smartwatchManagerDelegate` and registers the manager with
///    its alert manager, then calls `hostDataDidChange(.all)`.
/// 3. From then on the host calls `hostDataDidChange` and the alert methods; the
///    plugin reads from and calls the delegate.
/// 4. When the user deletes the watch, the plugin's `delete()` stops its work
///    and awaits `smartwatchManagerWantsDeletion`; the host drops it.
///
/// **Threads:** the host calls the `@MainActor` methods on the main actor and
/// expects them to return quickly: read and send to the watch asynchronously.
///
/// **Glucose alarms come only from the host.** A plugin passes on the alerts the
/// host forwards (`watchAlertDidIssue`, with their `SmartwatchGlucoseAlertType`)
/// and their retraction, and never raises a glucose alarm itself from glucose
/// values or limits it reads. Notices about the watch itself, such as no readings
/// for a while, a lost connection or a missing companion app, are the plugin's
/// own: on the watch, or through `issueAlert` like a pump's.
public protocol SmartwatchManager: DeviceManager {
    /// The host, set by the host after creating or restoring the manager. Keep it `weak`.
    var smartwatchManagerDelegate: SmartwatchManagerDelegate? { get set }

    /// Something the watch may show changed in the host.
    ///
    /// **Called** on the main actor right after the delegate is set (`.all`), as
    /// soon as a new glucose reading is stored, when the loop completes, and when
    /// presets, settings or the alert mute change. Changes that happen close
    /// together may arrive as one call. Read what changed from the delegate.
    @MainActor
    func hostDataDidChange(_ changes: SmartwatchHostDataChange)

    /// A host alert fired and may show on the watch.
    ///
    /// **Called** on the main actor each time the host issues or repeats an alert
    /// it forwards to watches (Loop and Trio forward their glucose alerts and
    /// follow their own mute). Use `glucoseAlertType` rather than the identifier
    /// to tell which glucose alert it is. This is a watch's only source of glucose
    /// alarms. Defaults to ignoring it.
    @MainActor
    func watchAlertDidIssue(_ alert: Alert, glucoseAlertType: SmartwatchGlucoseAlertType?, issuedAt: Date)

    /// A host alert was retracted and should clear on the watch.
    ///
    /// **Called** on the main actor when the host retracts an alert it forwarded,
    /// for example when glucose is back in range.
    @MainActor
    func watchAlertDidRetract(_ identifier: Alert.Identifier)

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

    /// Stops the manager and asks the host to remove it. Returns once the host has
    /// removed it.
    ///
    /// **Called** when the user deletes the watch, usually from the plugin's own
    /// settings. Stop everything (Bluetooth, timers, sending) and retract the
    /// plugin's alerts, then await
    /// `smartwatchManagerDelegate?.smartwatchManagerWantsDeletion(self)`. The
    /// default does only the last step.
    func delete() async
}

public extension SmartwatchManager {
    @MainActor
    func watchAlertDidIssue(_ alert: Alert, glucoseAlertType: SmartwatchGlucoseAlertType?, issuedAt: Date) {}
    @MainActor
    func watchAlertDidRetract(_ identifier: Alert.Identifier) {}
    @MainActor
    func watchHostDidLog(_ message: String) {}
    @MainActor
    func watchHostDidReceiveURL(_ url: URL) -> Bool { false }

    /// Override this default behaviour if the watch manager needs to complete tasks before being deleted
    func delete() async {
        await smartwatchManagerDelegate?.smartwatchManagerWantsDeletion(self)
    }
}
