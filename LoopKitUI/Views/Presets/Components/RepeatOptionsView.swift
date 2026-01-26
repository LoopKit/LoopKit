//
//  RepeatOptionsView.swift
//  Loop
//
//  Created by Pete Schwamb on 3/14/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import LoopKit
import SwiftUI

public struct RepeatOptionView: View {
    @ScaledMetric var dayTextSize: Double = 12

    let repeatOptions: PresetScheduleRepeatOptions
    
    public init(repeatOptions: PresetScheduleRepeatOptions) {
        self.repeatOptions = repeatOptions
    }

    private var selectedDays: [PresetScheduleRepeatOptions] {
        PresetScheduleRepeatOptions.allCases.filter { repeatOptions.contains($0) }
    }

    private var isSingleDay: Bool {
        selectedDays.count == 1
    }

    public var body: some View {
        if repeatOptions == .none {
            Text(repeatOptions.description)
                .tint(.secondary)
        } else if isSingleDay {
            Text(selectedDays[0].description)
                .foregroundColor(.secondary)
        } else {
            HStack(spacing: 4) {
                ForEach(PresetScheduleRepeatOptions.allCases, id: \.rawValue) { day in
                    Text(String(day.veryShortDescription))
                        .font(.system(size: dayTextSize))
                        .frame(width: dayTextSize+8, height: dayTextSize+8)
                        .background(
                            Circle()
                                .fill(repeatOptions.contains(day) ? Color.accentColor : Color.gray.opacity(0.2))
                        )
                        .foregroundColor(repeatOptions.contains(day) ? .white : .gray)
                }
            }
        }
    }
}

