//
//  DurationPickerView.swift
//  Loop
//
//  Created by Pete Schwamb on 1/29/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import LoopKit
import SwiftUI

public struct DurationPickerView: View {
    @Binding var durationType: PresetDuration
    @State private var lastUsedDuration: TimeInterval
    @State private var allowIndefinite: Bool

    // Available values (respecting min 5min and max 8hr constraints)
    private let availableHours = Array(0...8)
    private let availableMinutes = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55]

    public init(durationType: Binding<PresetDuration>, allowIndefinite: Bool = true) {
        self._durationType = durationType

        // Initialize lastUsedDuration based on current durationType or default to 1 hour
        let initialDuration: TimeInterval
        switch durationType.wrappedValue {
        case .duration(let interval):
            initialDuration = interval
        case .indefinite, .untilCarbsEntered:
            initialDuration = 3600 // 1 hour default
        }
        self._lastUsedDuration = State(initialValue: initialDuration)
        self.allowIndefinite = allowIndefinite
    }

    private var hours: Binding<Int> {
        Binding(
            get: {
                Int(lastUsedDuration / 3600)
            },
            set: { newHours in
                let existingMinutes = minutes.wrappedValue
                let newInterval = TimeInterval(newHours * 3600 + existingMinutes * 60)
                lastUsedDuration = newInterval
                if !isIndefinite.wrappedValue {
                    durationType = .duration(newInterval)
                }
            }
        )
    }

    private var minutes: Binding<Int> {
        Binding(
            get: {
                Int((lastUsedDuration.truncatingRemainder(dividingBy: 3600)) / 60)
            },
            set: { newMinutes in
                let existingHours = hours.wrappedValue
                let newInterval = TimeInterval(existingHours * 3600 + newMinutes * 60)
                lastUsedDuration = newInterval
                if !isIndefinite.wrappedValue {
                    durationType = .duration(newInterval)
                }
            }
        )
    }

    private var isIndefinite: Binding<Bool> {
        Binding(
            get: {
                if case .indefinite = durationType {
                    return true
                }
                return false
            },
            set: { isOn in
                if isOn {
                    durationType = .indefinite
                } else {
                    durationType = .duration(lastUsedDuration)
                }
            }
        )
    }

    var picker: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Picker("Hours", selection: hours) {
                    ForEach(availableHours, id: \.self) { hour in
                        Text("\(hour)")
                            .tag(hour)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 60)
                .clipped()
                .disabled(isIndefinite.wrappedValue)
                .opacity(isIndefinite.wrappedValue ? 0.5 : 1)

                Text("hour")
                    .foregroundColor(isIndefinite.wrappedValue ? .gray.opacity(0.5) : .gray)
            }

            HStack(spacing: 8) {
                Picker("Minutes", selection: minutes) {
                    ForEach(availableMinutes, id: \.self) { minute in
                        Text("\(minute)")
                            .tag(minute)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 60)
                .clipped()
                .disabled(isIndefinite.wrappedValue)
                .opacity(isIndefinite.wrappedValue ? 0.5 : 1)

                Text("min")
                    .foregroundColor(isIndefinite.wrappedValue ? .gray.opacity(0.5) : .gray)
            }
        }
        .padding(.horizontal)
        .onChange(of: hours.wrappedValue) { _, _ in
            enforceConstraints()
        }
        .onChange(of: minutes.wrappedValue) { _, _ in
            enforceConstraints()
        }
    }

    public var body: some View {
        VStack {
            if !isIndefinite.wrappedValue {
                picker
            }
            
            if allowIndefinite {
                HStack {
                    Text("Until I turn off")
                    Spacer()
                    Toggle("", isOn: isIndefinite)
                        .labelsHidden()
                }
            }
        }
    }

    private func enforceConstraints() {
        if !isIndefinite.wrappedValue {
            if lastUsedDuration < 300 { // Less than 5 minutes
                lastUsedDuration = 300
                durationType = .duration(300)
            } else if lastUsedDuration > 28800 { // More than 8 hours
                lastUsedDuration = 28800
                durationType = .duration(28800)
            } else {
                durationType = .duration(lastUsedDuration)
            }
        }
    }
}
