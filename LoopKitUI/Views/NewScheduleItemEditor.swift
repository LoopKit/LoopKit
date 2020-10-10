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
    enum SelectableTimes {
        case only(TimeInterval)
        case allExcept(Set<TimeInterval>)
    }

    @Binding var isPresented: Bool
    @State var item: RepeatingScheduleValue<Value>
    var initialItem: RepeatingScheduleValue<Value>
    var selectableTimes: SelectableTimes
    var valuePicker: (_ item: Binding<RepeatingScheduleValue<Value>>, _ availableWidth: CGFloat) -> ValuePicker
    var save: (RepeatingScheduleValue<Value>) -> Void

    init(
        isPresented: Binding<Bool>,
        initialItem: RepeatingScheduleValue<Value>,
        selectableTimes: SelectableTimes,
        @ViewBuilder valuePicker: @escaping (_ item: Binding<RepeatingScheduleValue<Value>>, _ availableWidth: CGFloat) -> ValuePicker,
        onSave save: @escaping (RepeatingScheduleValue<Value>) -> Void
    ) {
        self._isPresented = isPresented
        self._item = State(initialValue: initialItem)
        self.initialItem = initialItem
        self.selectableTimes = selectableTimes
        self.valuePicker = valuePicker
        self.save = save
    }

    var body: some View {
        VStack(spacing: 0) {
            ModalHeaderButtonBar(
                leading: { cancelButton },
                center: {
                    Text(LocalizedString("New Entry", comment: "Title for mini-modal to add a new schedule entry"))
                        .font(.headline)
                },
                trailing: { addButton }
            )

            ScheduleItemPicker(
                item: $item,
                isTimeSelectable: isTimeSelectable,
                valuePicker: { self.valuePicker(self.$item, $0) }
            )
            .padding(.horizontal)
            .background(
                RoundedCorners(radius: 10, corners: [.bottomLeft, .bottomRight])
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .padding(.horizontal)
    }

    func isTimeSelectable(_ time: TimeInterval) -> Bool {
        switch selectableTimes {
        case .only(let selectableTime):
            return time == selectableTime
        case .allExcept(let unavailableTimes):
            return !unavailableTimes.contains(time)
        }
    }

    var addButton: some View {
        Button(
            action: {
                withAnimation {
                    self.save(self.item)
                    self.isPresented = false
                }
            }, label: {
                Text(LocalizedString("Add", comment: "Button text to confirm adding a new schedule item"))
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
                Text(LocalizedString("Cancel", comment: "Button text to cancel adding a new schedule item"))
            }
        )
    }
}
