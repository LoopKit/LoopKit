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
    var syncSchedule: (_ items: [RepeatingScheduleValue<Double>], _ completion: @escaping (Result<BasalRateSchedule, Error>) -> Void) -> Void
    var save: (BasalRateSchedule) -> Void
    let mode: PresentationMode

    /// - Precondition: `supportedBasalRates` is nonempty and sorted in ascending order.
    public init(
        schedule: BasalRateSchedule?,
        supportedBasalRates: [Double],
        maximumBasalRate: Double?,
        maximumScheduleEntryCount: Int,
        syncSchedule: @escaping (
            _ items: [RepeatingScheduleValue<Double>],
            _ completion: @escaping (Result<BasalRateSchedule, Error>) -> Void
        ) -> Void,
        onSave save: @escaping (BasalRateSchedule) -> Void,
        mode: PresentationMode = .modal
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

        self.guardrail = Guardrail(
            absoluteBounds: supportedBasalRates.first!...supportedBasalRates.last!,
            recommendedBounds: supportedBasalRates.dropFirst().first!...supportedBasalRates.last!,
            unit: .internationalUnitsPerHour
        )
        self.maximumScheduleEntryCount = maximumScheduleEntryCount
        self.syncSchedule = syncSchedule
        self.save = save
        self.mode = mode
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
            message: Text("One or more of the values you have entered are outside of what Tidepool generally recommends.", comment: "Alert message for confirming basal rates outside the recommended range")
        )
    }
    
    private var savingMechanism: SavingMechanism<DailyQuantitySchedule<Double>> {
        switch mode {
        case .modal:
            return .asynchronous { quantitySchedule, completion in
                self.syncSchedule(quantitySchedule.items) { result in
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
        case .flow:
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
