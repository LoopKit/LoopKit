//
//  DurationPicker.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 7/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


public struct DurationPicker: UIViewRepresentable {
    @Binding public var duration: TimeInterval
    public var validDurationRange: ClosedRange<TimeInterval>
    public var minuteInterval: Int

    public init(duration: Binding<TimeInterval>, validDurationRange: ClosedRange<TimeInterval>, minuteInterval: Int = 15) {
        self._duration = duration
        self.validDurationRange = validDurationRange
        self.minuteInterval = minuteInterval
    }

    public func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .countDownTimer
        picker.addTarget(context.coordinator, action: #selector(Coordinator.pickerValueChanged(_:)), for: .valueChanged)
        return picker
    }

    public func updateUIView(_ picker: UIDatePicker, context: Context) {
        picker.countDownDuration = duration.clamped(to: validDurationRange)
        picker.minuteInterval = minuteInterval
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final public class Coordinator {
        var parent: DurationPicker

        init(_ parent: DurationPicker) {
            self.parent = parent
        }

        @objc func pickerValueChanged(_ picker: UIDatePicker) {
            parent.duration = picker.countDownDuration.clamped(to: parent.validDurationRange)
        }
    }
}
