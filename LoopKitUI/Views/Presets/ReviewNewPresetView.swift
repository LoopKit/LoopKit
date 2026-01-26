//
//  ReviewNewPresetView.swift
//  Loop
//
//  Created by Pete Schwamb on 3/6/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import LoopAlgorithm
import LoopKit
import SwiftUI

struct ReviewNewPresetView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var preset: NewCustomPreset
    @Binding var path: NavigationPath
    var scheduledRange: ClosedRange<LoopQuantity>
    var onCancel: () -> Void
    var onComplete: (_ startPreset: Bool) -> Void

    // Add a timer to trigger updates
    @State private var currentDate = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Computed property to check if start date is too soon
    private var isStartDateTooSoon: Bool {
        guard let startDate = preset.startDate, preset.savePreset else { return false }
        return startDate < currentDate.addingTimeInterval(60)
    }

    var body: some View {
        CardSectionScrollView {
            VStack(alignment: .leading) {
                Text("New Preset")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 40)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Review Settings")
                    .fontWeight(.semibold)
                Text("Review your preset settings below. To make any changes, navigate back to the setting you’d like to edit. You can edit these settings after saving your preset as well.")
                    .font(.footnote)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor)
            .cornerRadius(10)
            .padding(.top, 10)

            CardSection("Temporary Settings Adjustments") {
                InsulinNeedsAdjustmentPreview(insulinPercentage: preset.insulinMultiplier * 100, guardrail: Guardrail.presetInsulinNeeds)
            }

            CardSection {
                CorrectionRangePreview(
                    range: preset.correctionRange,
                    guardrail: Guardrail.temporaryPresetCorrectionRange,
                    scheduledRange: scheduledRange,
                    veryHighInsulinNeeds: preset.veryHighInsulinNeeds
                )
            }

            // Name Field
            if preset.savePreset {
                CardSection {
                    HStack {
                        Text("Name")
                            .font(.body)

                        Spacer()

                        Text(preset.name)
                            .font(.body)
                            .foregroundColor(.secondary)

                    }
                }
            }

            // Duration Section
            CardSection {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Duration")
                            .foregroundColor(.primary)
                        Spacer()
                        Group {
                            if let duration = preset.duration {
                                Text(duration.localizedTitle)
                            } else {
                                Text("Required")
                            }
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }

            // Schedule Toggle
            if preset.savePreset, let startDate = preset.startDate {
                CardSection {
                    HStack {
                        if preset.repeatOptions != .none  {
                            Text("Start Date")
                        } else {
                            Text("Start at")
                        }
                        Spacer()
                        Text(DateFormatter.localizedString(from: startDate, dateStyle: .short, timeStyle: .short))
                            .foregroundColor(.secondary)
                    }
                    if preset.repeatOptions != .none {
                        Divider()
                        HStack {
                            Text("Repeat weekly on")
                            Spacer()
                            RepeatOptionView(repeatOptions: preset.repeatOptions)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Text("Tidepool Loop will always ask you to confirm before turning on a scheduled preset.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.top, 4)

            }
        } actionArea: {
            if isStartDateTooSoon {
                WarningView(
                    title: Text("Invalid Start Time"),
                    caption: Text("Start time must be at least 1 minute in the future.")
                )
            }

            if preset.savePreset, preset.startDate != nil {
                Button("Save and Schedule for Later") {
                    onComplete(false)
                }
                .buttonStyle(ActionButtonStyle(.primary))
                .disabled(isStartDateTooSoon)
            } else if preset.savePreset {
                VStack {
                    Button("Start Preset") {
                        onComplete(true)
                    }
                    .buttonStyle(ActionButtonStyle(.primary))
                    Button("Save for Later") {
                        onComplete(false)
                    }
                    .buttonStyle(ActionButtonStyle(.secondary))
                }
            } else {
                Button("Start Preset") {
                    onComplete(true)
                }
                .buttonStyle(ActionButtonStyle(.primary))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Create a Preset")
        .edgesIgnoringSafeArea([.top])
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cancel") {
                    onCancel()
                }
            }
        }
        // Update currentDate every second
        .onReceive(timer) { _ in
            currentDate = Date()
        }
    }
}
