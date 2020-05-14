//
//  ScheduleEditor.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/24/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit


struct ScheduleEditor<Value: Equatable, ValueContent: View, ValuePicker: View, ActionAreaContent: View>: View {
    var title: Text
    var description: Text
    var initialScheduleItems: [RepeatingScheduleValue<Value>]
    @Binding var scheduleItems: [RepeatingScheduleValue<Value>]
    var defaultFirstScheduleItemValue: Value
    var scheduleItemLimit: Int
    var valueContent: (_ value: Value, _ isEditing: Bool) -> ValueContent
    var valuePicker: (_ item: Binding<RepeatingScheduleValue<Value>>, _ availableWidth: CGFloat) -> ValuePicker
    var actionAreaContent: ActionAreaContent
    var save: ([RepeatingScheduleValue<Value>]) -> Void

    @State var editingIndex: Int?

    @State var isAddingNewItem = false {
        didSet {
            if isAddingNewItem {
                editingIndex = nil
            }
        }
    }

    @State var tableDeletionState: TableDeletionState = .disabled {
        didSet {
            if tableDeletionState == .enabled {
                editingIndex = nil
            }
        }
    }

    @Environment(\.dismiss) var dismiss

    init(
        title: Text,
        description: Text,
        scheduleItems: Binding<[RepeatingScheduleValue<Value>]>,
        initialScheduleItems: [RepeatingScheduleValue<Value>],
        defaultFirstScheduleItemValue: Value,
        scheduleItemLimit: Int = 48,
        @ViewBuilder valueContent: @escaping (_ value: Value, _ isEditing: Bool) -> ValueContent,
        @ViewBuilder valuePicker: @escaping (_ item: Binding<RepeatingScheduleValue<Value>>, _ availableWidth: CGFloat) -> ValuePicker,
        @ViewBuilder actionAreaContent: () -> ActionAreaContent,
        onSave save: @escaping ([RepeatingScheduleValue<Value>]) -> Void
    ) {
        self.title = title
        self.description = description
        self.initialScheduleItems = initialScheduleItems
        self._scheduleItems = scheduleItems
        self.defaultFirstScheduleItemValue = defaultFirstScheduleItemValue
        self.scheduleItemLimit = scheduleItemLimit
        self.valueContent = valueContent
        self.valuePicker = valuePicker
        self.actionAreaContent = actionAreaContent()
        self.save = save
    }

    var body: some View {
        ZStack {
            NavigationView {
                ConfigurationPage(
                    title: title,
                    isSaveButtonEnabled: isSaveButtonEnabled,
                    cards: {
                        // TODO: Remove conditional when Swift 5.3 ships
                        // https://bugs.swift.org/browse/SR-11628
                        if true {
                            Card {
                                SettingDescription(text: description)
                                Splat(Array(scheduleItems.enumerated()), id: \.element.startTime) { index, item in
                                    self.itemView(for: item, at: index)
                                }
                            }
                        }
                    },
                    actionAreaContent: {
                        actionAreaContent
                            .padding(.horizontal)
                            .transition(AnyTransition.opacity.combined(with: .move(edge: .bottom)))
                    },
                    onSave: {
                        self.save(self.scheduleItems)
                    }
                )
                .navigationBarTitle("", displayMode: .inline)
                .navigationBarItems(
                    leading: cancelButton,
                    trailing: trailingNavigationItems
                )
            }
            .disabled(isAddingNewItem)
            .zIndex(0)

            if isAddingNewItem {
                DarkenedOverlay()
                    .zIndex(1)

                NewScheduleItemEditor(
                    isPresented: $isAddingNewItem,
                    initialItem: initialNewScheduleItem,
                    selectableTimes: scheduleItems.isEmpty
                        ? .only(.hours(0))
                        : .allExcept(Set(scheduleItems.map { $0.startTime })),
                    valuePicker: valuePicker,
                    onSave: { newItem in
                        self.scheduleItems.append(newItem)
                        self.scheduleItems.sort(by: { $0.startTime < $1.startTime })
                    }
                )
                .transition(
                    AnyTransition
                        .move(edge: .bottom)
                        .combined(with: .opacity)
                )
                .zIndex(2)
            }
        }
    }

    private var isSaveButtonEnabled: Bool {
        !scheduleItems.isEmpty && scheduleItems != initialScheduleItems
    }

    private func itemView(for item: RepeatingScheduleValue<Value>, at index: Int) -> some View {
        Deletable(
            tableDeletionState: $tableDeletionState,
            index: index,
            isDeletable: index != 0,
            onDelete: {
                withAnimation {
                    // In Xcode 11.4, using `remove(at:)` here is ambiguous to the compiler.
                    // Remove a length one subrange instead.
                    self.scheduleItems.removeSubrange(index...index)

                    if self.scheduleItems.count == 1 {
                        self.tableDeletionState = .disabled
                    }
                }
            }
        ) {
            ScheduleItemView(
                time: item.startTime,
                isEditing: isEditing(index),
                valueContent: {
                    valueContent(item.value, isEditing(index).wrappedValue)
                },
                expandedContent: {
                    ScheduleItemPicker(
                        item: $scheduleItems[index],
                        isTimeSelectable: { self.isTimeSelectable($0, at: index) },
                        valuePicker: { self.valuePicker(self.$scheduleItems[index], $0) }
                    )
                }
            )
        }
    }

    private func isEditing(_ index: Int) -> Binding<Bool> {
        Binding(
            get: { index == self.editingIndex },
            set: { isNowEditing in
                self.editingIndex = isNowEditing ? index : nil
            }
        )
    }

    private func isTimeSelectable(_ time: TimeInterval, at index: Int) -> Bool {
        if index == scheduleItems.startIndex {
            return time == .hours(0)
        }

        let priorTime = scheduleItems[index - 1].startTime
        guard time > priorTime else {
            return false
        }

        if index < scheduleItems.endIndex - 1 {
            let nextTime = scheduleItems[index + 1].startTime
            guard time < nextTime else {
                return false
            }
        }

        return true
    }

    private var initialNewScheduleItem: RepeatingScheduleValue<Value> {
        assert(scheduleItems.count <= scheduleItemLimit)

        if scheduleItems.isEmpty {
            return RepeatingScheduleValue(startTime: .hours(0), value: defaultFirstScheduleItemValue)
        }

        if scheduleItems.last!.startTime == .hours(23.5) {
            let firstItemFollowedByOpening = scheduleItems.adjacentPairs().first(where: { item, next in
                next.startTime - item.startTime > .minutes(30)
            })!.0
            return RepeatingScheduleValue(
                startTime: firstItemFollowedByOpening.startTime + .minutes(30),
                value: firstItemFollowedByOpening.value
            )
        } else {
            return RepeatingScheduleValue(
                startTime: scheduleItems.last!.startTime + .minutes(30),
                value: scheduleItems.last!.value
            )
        }
    }

    private var trailingNavigationItems: some View {
        // TODO: SwiftUI's alignment of these buttons in the navigation bar is a little funky.
        // Tapping 'Edit' then 'Done' can shift '+' slightly.
        HStack(spacing: 24) {
            if tableDeletionState == .disabled {
                editButton
            } else {
                doneButton
            }

            addButton
        }
    }

    var cancelButton: some View {
        Button(action: dismiss, label: { Text("Cancel") })
    }

    var editButton: some View {
        Button(
            action: {
                withAnimation {
                    self.tableDeletionState = .enabled
                }
            },
            label: {
                Text("Edit")
            }
        )
        .disabled(scheduleItems.count == 1)
    }

    var doneButton: some View {
        Button(
            action: {
                withAnimation {
                    self.tableDeletionState = .disabled
                }
            },
            label: {
                Text("Done").bold()
            }
        )
    }

    var addButton: some View {
        Button(
            action: {
                withAnimation {
                    self.isAddingNewItem = true
                }
            },
            label: {
                Image(systemName: "plus")
                    .imageScale(.large)
                    .contentShape(Rectangle())
            }
        )
        .disabled(tableDeletionState != .disabled || scheduleItems.count > scheduleItemLimit)
    }
}

struct DarkenedOverlay: View {
    var body: some View {
        Rectangle()
            .fill(Color.black.opacity(0.3))
            .edgesIgnoringSafeArea(.all)
    }
}
