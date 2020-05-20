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
    var valuePicker: (_ availableWidth: CGFloat) -> ValuePicker

    init(
        item: Binding<RepeatingScheduleValue<Value>>,
        isTimeSelectable: @escaping (TimeInterval) -> Bool,
        @ViewBuilder valuePicker: @escaping (_ availableWidth: CGFloat) -> ValuePicker
    ) {
        self._item = item
        self.isTimeSelectable = isTimeSelectable
        self.valuePicker = valuePicker
    }

    var body: some View {
        GeometryReader { geometry in
            HStack {
                Spacer()
                HStack(spacing: 0) {
                    TimePicker(
                        offsetFromMidnight: self.$item.startTime,
                        bounds: 0...TimeInterval(hours: 23.5),
                        stride: .hours(0.5),
                        isTimeExcluded: { !self.isTimeSelectable($0) }
                    )
                    .frame(width: geometry.size.width / 3)
                    .clipped()
                    .accessibility(identifier: "time_picker")

                    self.valuePicker(/* availableWidth: */ 2/3 * geometry.size.width)
                }
                Spacer()
            }
        }
        .frame(height: 216)
    }
}
