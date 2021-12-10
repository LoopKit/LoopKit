//
//  TimePicker.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/23/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


/// Binds a `TimeInterval` describing an offset from midnight to a selected picker value.
///
/// For example, a value of `0` corresponds to midnight, while a value of `7200` corresponds to 2:00 AM.
///
/// The offset is not relative to the current date. Use `TimePicker` for selecting the time of a recurring daily event, _not_ for selecting the time at which an alarm should sound later this afternoon.
public struct TimePicker: View {
    @Binding private var offsetFromMidnight: TimeInterval
    private let allValues: [TimeInterval]
    private let fixedMidnight = Calendar.current.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))

    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short
        return dateFormatter
    }()

    public init(
        offsetFromMidnight: Binding<TimeInterval>,
        bounds: ClosedRange<TimeInterval>,
        stride: TimeInterval,
        isTimeExcluded: (TimeInterval) -> Bool = { _ in false }
    ) {
        self._offsetFromMidnight = offsetFromMidnight
        self.allValues = Swift.stride(from: bounds.lowerBound, through: bounds.upperBound, by: stride)
            .filter { !isTimeExcluded($0) }
    }

    public var body: some View {
        Picker(selection: $offsetFromMidnight, label: Text(LocalizedString("Time", comment: "Label for offset from midnight picker"))) {
            ForEach(allValues, id: \.self) { time in
                self.text(for: time)
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
    }

    private func text(for time: TimeInterval) -> Text {
        let dayAtTime = fixedMidnight.addingTimeInterval(time)
        return Text("\(dayAtTime, formatter: Self.dateFormatter)")
            .foregroundColor(.primary)
    }
}
