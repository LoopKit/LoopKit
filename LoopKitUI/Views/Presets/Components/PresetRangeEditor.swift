//
//  EditPressRangeView.swift
//  Loop
//
//  Created by Pete Schwamb on 12/17/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//
import SwiftUI
import LoopAlgorithm
import LoopKit

public struct PresetRangeEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.guidanceColors) private var guidanceColors
    @EnvironmentObject private var displayGlucosePreference: DisplayGlucosePreference


    @State private var presentInfoView: Bool = false
    @Binding var range: ClosedRange<LoopQuantity>?
    var guardrail: Guardrail<LoopQuantity>
    private var scheduledRange: ClosedRange<LoopQuantity>
    private var allowsScheduledRange: Bool
    private var isPreMeal: Bool
    
    let suspendThresholdQuantity: () -> LoopQuantity?

    public init(range: Binding<ClosedRange<LoopQuantity>?>, guardrail: Guardrail<LoopQuantity>, scheduledRange: ClosedRange<LoopQuantity>, allowsScheduledRange: Bool = true, isPreMeal: Bool, suspendThresholdQuantity: @escaping () -> LoopQuantity?) {
        self._range = range
        self.guardrail = guardrail
        self.scheduledRange = scheduledRange
        self.allowsScheduledRange = allowsScheduledRange
        self.isPreMeal = isPreMeal
        self.suspendThresholdQuantity = suspendThresholdQuantity
    }

    var displayedRange: ClosedRange<LoopQuantity> {
        return range ?? scheduledRange
    }

    func boundText(for bound: LoopQuantity) -> Text {
        let color = guardrail.color(for: bound, guidanceColors: guidanceColors)
        let text = displayGlucosePreference.format(bound, includeUnit: false)
        switch guardrail.classification(for: bound) {
        case .withinRecommendedRange:
            return Text(text)
                .foregroundColor(range == nil ? .secondary : .accentColor)
                .font(.system(size: 42, weight: .semibold))
        case .outsideRecommendedRange:
            return (
                Text(Image(systemName: "exclamationmark.triangle.fill"))
                    .font(.system(size: 29, weight: .regular))
                    .baselineOffset(3.0)
                    .foregroundColor(color) +
                Text(text)
                    .foregroundColor(color)
                    .font(.system(size: 42, weight: .semibold))
                )
        }
    }

    public var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                HStack {
                    Text("Correction Range")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                    Button(action: {
                        presentInfoView = true;
                    }) {
                        Image(systemName: "info.circle")
                    }
                }
                .padding(.top, 10)


                Text("Set your correction range")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)

                Text("To reduce the risk of highs or lows, you may want to set an adjusted range if you think your glucose will vary more than usual.")
                    .multilineTextAlignment(.center)

                if allowsScheduledRange {
                    Toggle("Use Scheduled Range", isOn: Binding(get: {
                        range == nil
                    }, set: { newValue in
                        withAnimation {
                            if (newValue) {
                                range = nil
                            } else {
                                range = scheduledRange
                            }
                        }
                    }))
                    .padding(.vertical)
                }
            }

            VStack(spacing: 0) {
                if (range == nil) {
                    Text("Currently Scheduled Correction Range")
                } else {
                    Text("Adjusted Range")

                }

                (
                    boundText(for: (displayedRange).lowerBound) +
                    Text("-").foregroundColor(.secondary)
                        .font(.system(size: 42, weight: .light))
                    +
                    boundText(for: (displayedRange).upperBound)
                )
                .accessibilityIdentifier("text_AdjustedCorrectionRange")


                Text(displayGlucosePreference.unit.localizedShortUnitString)
                    .foregroundColor(.secondary)
            }

            if range != nil {
                Divider()
                    .animation(.default, value: range != nil)

                GlucoseRangePicker(range: Binding(
                    get: { displayedRange },
                    set: { range = $0 }),
                                   unit: displayGlucosePreference.unit,
                                   minValue: suspendThresholdQuantity(),
                                   guardrail: guardrail)
                .padding(.vertical, -20)
            }

            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(.accentColor)

                tipText.font(.system(size: 14))
            }
            .padding()
            .overlay( /// apply a rounded border
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.gray, lineWidth: 1)
            )
            .padding(.bottom)
        }
        .font(.subheadline)
        .sheet(isPresented: $presentInfoView) {
            CorrectionRangeInformationView()
        }
    }


    private var tipText: some View {
         Group {
             if isPreMeal {
                 Text("To help avoid post-meal highs, set a range ")
                  + Text("lower")
                     .italic()
                     .bold()
                  + Text(" than your typical correction range.")
             } else {
                 Text("To help avoid lows, set a range ")
                  + Text("higher")
                     .italic()
                     .bold()
                  + Text(" than your typical correction range.")
             }
         }
     }
}
