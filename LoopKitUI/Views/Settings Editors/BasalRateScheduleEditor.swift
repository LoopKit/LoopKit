//
//  BasalRateScheduleEditor.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/20/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit


public struct BasalRateScheduleEditor: View {
    var schedule: DailyQuantitySchedule<Double>?
    var supportedBasalRates: [Double]
    var guardrail: Guardrail<HKQuantity>
    var maximumScheduleEntryCount: Int
    var syncSchedule: PumpManager.SyncSchedule?
    var save: (BasalRateSchedule) -> Void
    let mode: PresentationMode

    /// - Precondition: `supportedBasalRates` is nonempty and sorted in ascending order.
    public init(
        schedule: BasalRateSchedule?,
        supportedBasalRates: [Double],
        maximumBasalRate: Double?,
        maximumScheduleEntryCount: Int,
        syncSchedule: PumpManager.SyncSchedule?,
        onSave save: @escaping (BasalRateSchedule) -> Void,
        mode: PresentationMode = .settings
    ) {
        self.schedule = schedule.map { schedule in
            DailyQuantitySchedule(
                unit: .internationalUnitsPerHour,
                dailyItems: schedule.items
            )!
        }

        if let maxBasal = maximumBasalRate {
            let partitioningIndex = supportedBasalRates.partitioningIndex(where: { $0 > maxBasal })
            self.supportedBasalRates = Array(supportedBasalRates[..<partitioningIndex])
        } else {
            self.supportedBasalRates = supportedBasalRates
        }

        self.guardrail = Guardrail.basalRate(supportedBasalRates: supportedBasalRates)
        self.maximumScheduleEntryCount = maximumScheduleEntryCount
        self.syncSchedule = syncSchedule
        self.save = save
        self.mode = mode
    }
    
    public init(
        viewModel: TherapySettingsViewModel,
        didSave: (() -> Void)? = nil
    ) {
        self.init(
            schedule: viewModel.therapySettings.basalRateSchedule,
            supportedBasalRates: viewModel.pumpSupportedIncrements!()!.basalRates ,
            maximumBasalRate: viewModel.therapySettings.maximumBasalRatePerHour,
            maximumScheduleEntryCount: viewModel.pumpSupportedIncrements!()!.maximumBasalScheduleEntryCount,
            syncSchedule: viewModel.syncPumpSchedule?(),
            onSave: { [weak viewModel] newBasalRates in
                viewModel?.saveBasalRates(basalRates: newBasalRates)
                didSave?()
            },
            mode: viewModel.mode
        )
    }

    public var body: some View {
        QuantityScheduleEditor(
            title: Text(TherapySetting.basalRate.title),
            description: description,
            schedule: schedule,
            unit: .internationalUnitsPerHour,
            selectableValues: supportedBasalRates,
            guardrail: guardrail,
            quantitySelectionMode: .fractional,
            defaultFirstScheduleItemValue: guardrail.absoluteBounds.lowerBound,
            scheduleItemLimit: maximumScheduleEntryCount,
            confirmationAlertContent: confirmationAlertContent,
            guardrailWarning: {
                BasalRateGuardrailWarning(
                    crossedThresholds: $0,
                    isZeroUnitRateSelectable: self.supportedBasalRates.first! == 0
                )
            },
            onSave: savingMechanism,
            mode: mode,
            settingType: .basalRate
        )
    }
    
    private var description: Text {
        Text(TherapySetting.basalRate.descriptiveText)
    }

    private var confirmationAlertContent: AlertContent {
        AlertContent(
            title: Text("Save Basal Rates?", comment: "Alert title for confirming basal rates outside the recommended range"),
            message: Text(TherapySetting.basalRate.guardrailSaveWarningCaption)
        )
    }
    
    private var savingMechanism: SavingMechanism<DailyQuantitySchedule<Double>> {
        switch mode {
        case .settings:
            return .asynchronous { quantitySchedule, completion in
                precondition(self.syncSchedule != nil)
                self.syncSchedule?(quantitySchedule.items) { result in
                    switch result {
                    case .success(let syncedSchedule):
                        DispatchQueue.main.async {
                            self.save(syncedSchedule)
                        }
                        completion(nil)
                    case .failure(let error):
                        completion(error)
                    }
                }
            }
        case .acceptanceFlow:
            // TODO: get timezone from pump
            return .synchronous { quantitySchedule in
                let schedule = BasalRateSchedule(dailyItems: quantitySchedule.items, timeZone: .currentFixed)!
                self.save(schedule)
            }
        }
    }
}

private struct BasalRateGuardrailWarning: View {
    var crossedThresholds: [SafetyClassification.Threshold]
    var isZeroUnitRateSelectable: Bool

    var body: some View {
        assert(!crossedThresholds.isEmpty)

        let caption = self.isZeroUnitRateSelectable && crossedThresholds.allSatisfy({ $0 == .minimum })
            // ANNA TODO: ask MLee about this one
            ? Text("A value of 0 U/hr means you will be scheduled to receive no basal insulin.", comment: "Warning text for basal rate of 0 U/hr")
            : nil

        return GuardrailWarning(
            title: crossedThresholds.count == 1 ? singularWarningTitle(for: crossedThresholds.first!) : multipleWarningTitle,
            thresholds: crossedThresholds,
            caption: caption
        )
    }

    private func singularWarningTitle(for threshold: SafetyClassification.Threshold) -> Text {
        switch threshold {
        case .minimum where isZeroUnitRateSelectable:
            return Text("No Basal Insulin", comment: "Title text for the zero basal rate warning")
        case .minimum, .belowRecommended:
            return Text("Low Basal Rate", comment: "Title text for the low basal rate warning")
        case .aboveRecommended, .maximum:
            return Text("High Basal Rate", comment: "Title text for the high basal rate warning")
        }
    }

    private var multipleWarningTitle: Text {
        isZeroUnitRateSelectable && crossedThresholds.allSatisfy({ $0 == .minimum })
            ? Text("No Basal Insulin", comment: "Title text for the zero basal rate warning")
            : Text("Basal Rates", comment: "Title text for multi-value basal rate warning")
    }
}
