//
//  OverrideSelectionHistory.swift
//  LoopUI
//
//  Created by Anna Quinlan on 8/1/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import HealthKit

public class OverrideHistoryViewModel: ObservableObject {
    var overrides: [TemporaryScheduleOverride]
    var glucoseUnit: HKUnit
    var didEditOverride: ((TemporaryScheduleOverride) -> Void)?
    var didDeleteOverride: ((TemporaryScheduleOverride) -> Void)?

    public init(
        overrides: [TemporaryScheduleOverride],
        glucoseUnit: HKUnit
    ) {
        self.overrides = overrides
        self.glucoseUnit = glucoseUnit
    }
}

public struct OverrideSelectionHistory: View {
    @ObservedObject var model: OverrideHistoryViewModel
    private var quantityFormatter: QuantityFormatter
    private var glucoseNumberFormatter: NumberFormatter
    private var durationFormatter: DateComponentsFormatter
    private let autoBolusCarbsEnabled: Bool
    
    public init(model: OverrideHistoryViewModel, autoBolusCarbsEnabled: Bool) {
        self.model = model
        self.quantityFormatter = {
            let quantityFormatter = QuantityFormatter(for: model.glucoseUnit)
            return quantityFormatter
        }()
        self.glucoseNumberFormatter = quantityFormatter.numberFormatter
        self.durationFormatter = {
            let formatter = DateComponentsFormatter()

            formatter.allowedUnits = [.hour, .minute]
            formatter.unitsStyle = .short

            return formatter
        }()
        self.autoBolusCarbsEnabled = autoBolusCarbsEnabled
    }
    
    // Style conditionally based on iOS so we get a grouped list style
    public var body: some View {
        bodyContents
            .insetGroupedListStyle()
    }
    
    private var bodyContents: some View {
        List {
            ForEach(model.overrides, id: \.self) { override in
                Group {
                    // Don't show overrides in history that were never active
                    if override.actualEnd != .deleted {
                        Section {
                            NavigationLink(destination: self.detailView(for: override)) {
                                self.createCell(for: override)
                                .padding(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            }
                        }
                    }
                }
            }
        }
        .navigationBarTitle(Text(LocalizedString("Override History", comment: "Title for override history view")), displayMode: .large)
    }
    
    private func makeTargetRangeText(from targetRange: ClosedRange<HKQuantity>) -> String {
        guard
            let minTarget = glucoseNumberFormatter.string(from: targetRange.lowerBound.doubleValue(for: model.glucoseUnit)),
            let maxTarget = glucoseNumberFormatter.string(from: targetRange.upperBound.doubleValue(for: model.glucoseUnit))
        else {
            return ""
        }

        return String(format: LocalizedString("%1$@ – %2$@ %3$@", comment: "The format for a glucose target range. (1: min target)(2: max target)(3: glucose unit)"), minTarget, maxTarget, quantityFormatter.localizedUnitStringWithPlurality())
    }
    
    private func createCell(for override: TemporaryScheduleOverride) -> OverrideViewCell {
        let startTime = DateFormatter.localizedString(from: override.startDate, dateStyle: .none, timeStyle: .short)
        
        var targetRange: String = ""
        if let range = override.settings.targetRange {
            targetRange = makeTargetRangeText(from: range)
        }

        var duration: String {
            // Don't use the durationFormatter if the interval is infinite
            if !override.duration.isFinite && override.scheduledEndDate == override.actualEndDate  {
                return "∞"
            }
            return durationFormatter.string(from: override.startDate, to: override.actualEndDate)!
        }
        
        let insulinNeeds = override.settings.insulinNeedsScaleFactor
        let autoBolusCarbsActive = autoBolusCarbsEnabled ? override.settings.autoBolusCarbsActive : nil
        
        switch override.context {
        case .legacyWorkout:
            return OverrideViewCell(
                symbol: Text("🏃‍♂️"),
                name: Text("Workout", comment: "Title for workout override history cell"),
                targetRange: Text(targetRange),
                duration: Text(duration),
                subtitle: Text(startTime),
                insulinNeedsScaleFactor: insulinNeeds,
                autoBolusCarbsActive: autoBolusCarbsActive)
        case .preMeal:
            return OverrideViewCell(
                symbol: Text("🍽"),
                name: Text("Pre-Meal", comment: "Title for pre-meal override history cell"),
                targetRange: Text(targetRange),
                duration: Text(duration),
                subtitle: Text(startTime),
                insulinNeedsScaleFactor: insulinNeeds,
                autoBolusCarbsActive: autoBolusCarbsActive)
        case .preset(let preset):
            return OverrideViewCell(
                symbol: Text(preset.symbol),
                name: Text(preset.name),
                targetRange: Text(targetRange),
                duration: Text(duration),
                subtitle: Text(startTime),
                insulinNeedsScaleFactor: insulinNeeds,
                autoBolusCarbsActive: autoBolusCarbsActive)
        case .custom:
            return OverrideViewCell(
                symbol: Text("···"),
                name: Text("Custom", comment: "Title for custom override history cell"),
                targetRange: Text(targetRange),
                duration: Text(duration),
                subtitle: Text(startTime),
                insulinNeedsScaleFactor: insulinNeeds,
                autoBolusCarbsActive: autoBolusCarbsActive)
        }
    }
    
    private func title(for override: TemporaryScheduleOverride) -> String {
        switch override.context {
        case .legacyWorkout:
            return LocalizedString("🏃‍♂️ Workout", comment: "Workout override preset title")
        case .preMeal:
            return LocalizedString("🍽 Pre-Meal", comment: "Premeal override preset title")
        case .preset(let preset):
            let symbol = preset.symbol
            let name = preset.name
            let format = LocalizedString("%1$@ %2$@", comment: "The format for an override symbol and name (1: symbol)(2: name)")
            return String(format: format, symbol, name)
        case .custom:
            return LocalizedString("Custom Override", comment: "Custom override preset title")
        }
    }
    
    private func detailView(for override: TemporaryScheduleOverride) -> some View {
        let editorTitle = title(for: override)
        return HistoricalOverrideDetailView(
            override: override,
            glucoseUnit: model.glucoseUnit,
            delegate: nil,
            autoBolusCarbsEnabled: autoBolusCarbsEnabled
        ).navigationBarTitle(editorTitle)
    }
}
