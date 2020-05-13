//
//  ScheduleItemPicker.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/24/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit


struct ScheduleItemPicker<Value, ValuePicker: View>: View {
    @Binding var item: RepeatingScheduleValue<Value>
    var isTimeSelectable: (TimeInterval) -> Bool
    var valuePicker: ValuePicker

    @State private var pickerLabelWidth: CGFloat?

    init(
        item: Binding<RepeatingScheduleValue<Value>>,
        isTimeSelectable: @escaping (TimeInterval) -> Bool,
        @ViewBuilder valuePicker: () -> ValuePicker
    ) {
        self._item = item
        self.isTimeSelectable = isTimeSelectable
        self.valuePicker = valuePicker()
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                TimePicker(
                    offsetFromMidnight: self.$item.startTime,
                    bounds: 0...TimeInterval(hours: 23.5),
                    stride: .hours(0.5),
                    isTimeExcluded: { !self.isTimeSelectable($0) }
                )
                    .frame(width: geometry.size.width / 3)
                    .padding(.horizontal)
                    .clipped()

                self.valuePicker
                    .frame(width: geometry.size.width / 3)
                    // Ensure a quantity picker's label is not clipped
                    .onPreferenceChange(QuantityPickerUnitLabelWidthKey.self) { unitLabelWidth in
                        self.pickerLabelWidth = unitLabelWidth
                    }
                    .padding(.trailing, self.pickerLabelWidth ?? 0 + 8)
                    .clipped()
            }
        }
        .frame(height: 216)
    }
}
