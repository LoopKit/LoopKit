//
//  NewScheduleItemEditor.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 5/7/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit


struct NewScheduleItemEditor<Value, ValuePicker: View>: View {
    @Binding var isPresented: Bool
    @State var item: RepeatingScheduleValue<Value>
    var initialItem: RepeatingScheduleValue<Value>
    var unavailableTimes: Set<TimeInterval>
    var valuePicker: (_ item: Binding<RepeatingScheduleValue<Value>>) -> ValuePicker
    var save: (RepeatingScheduleValue<Value>) -> Void

    init(
        isPresented: Binding<Bool>,
        initialItem: RepeatingScheduleValue<Value>,
        unavailableTimes: Set<TimeInterval>,
        @ViewBuilder valuePicker: @escaping (_ item: Binding<RepeatingScheduleValue<Value>>) -> ValuePicker,
        onSave save: @escaping (RepeatingScheduleValue<Value>) -> Void
    ) {
        self._isPresented = isPresented
        self._item = State(initialValue: initialItem)
        self.initialItem = initialItem
        self.unavailableTimes = unavailableTimes
        self.valuePicker = valuePicker
        self.save = save
    }

    var body: some View {
        VStack(spacing: 0) {
            ModalHeaderButtonBar(
                leading: { cancelButton },
                center: {
                    Text("New Entry", comment: "Title for mini-modal to add a new schedule entry")
                        .font(.headline)
                },
                trailing: { addButton }
            )

            ScheduleItemPicker(
                item: $item,
                isTimeSelectable: { !self.unavailableTimes.contains($0) },
                valuePicker: { valuePicker($item) }
            )
            .padding(.horizontal)
            .background(
                RoundedCorners(radius: 10, corners: [.bottomLeft, .bottomRight])
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .padding(.horizontal)
    }

    var addButton: some View {
        Button(
            action: {
                withAnimation {
                    self.save(self.item)
                    self.isPresented = false
                }
            }, label: {
                Text("Add", comment: "Button text to confirm adding a new schedule item")
            }
        )
    }

    var cancelButton: some View {
        Button(
            action: {
                withAnimation {
                    self.isPresented = false
                }
            }, label: {
                Text("Cancel", comment: "Button text to cancel adding a new schedule item")
            }
        )
    }
}
