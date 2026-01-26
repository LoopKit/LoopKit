//
//  DayPickerPopup.swift
//  Loop
//
//  Created by Pete Schwamb on 3/11/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit

public struct DayPickerPopup: View {
    @Binding var selectedDays: PresetScheduleRepeatOptions

    public init(selectedDays: Binding<PresetScheduleRepeatOptions>) {
        self._selectedDays = selectedDays
    }
    
    public var body: some View {
        VStack(spacing: 10) {
            Text("Select Days")
                .font(.headline)

            ForEach(PresetScheduleRepeatOptions.allCases, id: \.rawValue) { day in
                MultipleSelectionRow(
                    day: day,
                    isSelected: selectedDays.contains(day)
                ) {
                    toggleDay(day)
                }
            }
        }
        .padding()
        .frame(width: 250)
    }

    private func toggleDay(_ day: PresetScheduleRepeatOptions) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
    }
    
    // Selection row (unchanged)
    private struct MultipleSelectionRow: View {
        let day: PresetScheduleRepeatOptions
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack {
                    Text(day.description)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.vertical, 4)
            }
            .foregroundColor(.primary)
        }
    }
}
