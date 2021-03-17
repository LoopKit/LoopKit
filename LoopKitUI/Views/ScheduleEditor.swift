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

enum SavingMechanism<Value> {
    case synchronous((_ value: Value) -> Void)
    case asynchronous((_ value: Value, _ completion: @escaping (Error?) -> Void) -> Void)

    func pullback<NewValue>(_ transform: @escaping (NewValue) -> Value) -> SavingMechanism<NewValue> {
        switch self {
        case .synchronous(let save):
            return .synchronous { newValue in save(transform(newValue)) }
        case .asynchronous(let save):
            return .asynchronous { newValue, completion in
                save(transform(newValue), completion)
            }
        }
    }
}

enum SaveConfirmation {
    case required(AlertContent)
    case notRequired
}

struct ScheduleEditor<Value: Equatable, ValueContent: View, ValuePicker: View, ActionAreaContent: View>: View {
    fileprivate enum PresentedAlert {
        case saveConfirmation(AlertContent)
        case saveError(Error)
    }

    var title: Text
    var description: Text
    var initialScheduleItems: [RepeatingScheduleValue<Value>]
    @Binding var scheduleItems: [RepeatingScheduleValue<Value>]
    var defaultFirstScheduleItemValue: Value
    var scheduleItemLimit: Int
    var saveConfirmation: SaveConfirmation
    var valueContent: (_ value: Value, _ isEditing: Bool) -> ValueContent
    var valuePicker: (_ item: Binding<RepeatingScheduleValue<Value>>, _ availableWidth: CGFloat) -> ValuePicker
    var actionAreaContent: ActionAreaContent
    var savingMechanism: SavingMechanism<[RepeatingScheduleValue<Value>]>
    var mode: SettingsPresentationMode
    var therapySettingType: TherapySetting
    
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

    @State var isSyncing = false

    @State private var presentedAlert: PresentedAlert?

    @Environment(\.dismiss) var dismiss
    @Environment(\.authenticate) var authenticate

    init(
        title: Text,
        description: Text,
        scheduleItems: Binding<[RepeatingScheduleValue<Value>]>,
        initialScheduleItems: [RepeatingScheduleValue<Value>],
        defaultFirstScheduleItemValue: Value,
        scheduleItemLimit: Int = 48,
        saveConfirmation: SaveConfirmation,
        @ViewBuilder valueContent: @escaping (_ value: Value, _ isEditing: Bool) -> ValueContent,
        @ViewBuilder valuePicker: @escaping (_ item: Binding<RepeatingScheduleValue<Value>>, _ availableWidth: CGFloat) -> ValuePicker,
        @ViewBuilder actionAreaContent: () -> ActionAreaContent,
        savingMechanism: SavingMechanism<[RepeatingScheduleValue<Value>]>,
        mode: SettingsPresentationMode = .settings,
        therapySettingType: TherapySetting = .none
    ) {
        self.title = title
        self.description = description
        self.initialScheduleItems = initialScheduleItems
        self._scheduleItems = scheduleItems
        self.defaultFirstScheduleItemValue = defaultFirstScheduleItemValue
        self.scheduleItemLimit = scheduleItemLimit
        self.saveConfirmation = saveConfirmation
        self.valueContent = valueContent
        self.valuePicker = valuePicker
        self.actionAreaContent = actionAreaContent()
        self.savingMechanism = savingMechanism
        self.mode = mode
        self.therapySettingType = therapySettingType
    }

    var body: some View {
        ZStack {
            configurationPage
            .disabled(isSyncing || isAddingNewItem)
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
    
    private var configurationPage: some View {
        switch mode {
        case .acceptanceFlow:
            return AnyView(page)
        case .settings:
            return AnyView(pageWithCancel)
        }
    }
        
    private var pageWithCancel: some View {
        switch saveButtonState {
        case .disabled, .loading:
            return AnyView(page
                .navigationBarBackButtonHidden(false)
                .navigationBarItems(leading: EmptyView(), trailing: trailingNavigationItems)
            )
        case .enabled:
            return AnyView(page
                .navigationBarBackButtonHidden(true)
                .navigationBarItems(leading: cancelButton, trailing: trailingNavigationItems)
            )
        }
    }
    
    private var page: some View {
        ConfigurationPage(
            title: title,
            actionButtonTitle: Text(mode.buttonText),
            actionButtonState: saveButtonState,
            cards: {
                Card {
                    SettingDescription(text: description, informationalContent: {self.therapySettingType.helpScreen()})
                    Splat(Array(scheduleItems.enumerated()), id: \.element.startTime) { index, item in
                        self.itemView(for: item, at: index)
                    }
                }
            },
            actionAreaContent: {
                actionAreaContent
            },
            action: {
                switch self.saveConfirmation {
                case .required(let alertContent):
                    self.presentedAlert = .saveConfirmation(alertContent)
                case .notRequired:
                    self.startSaving()
                }
            }
        )
        .alert(item: $presentedAlert, content: alert(for:))
        .navigationBarTitle("", displayMode: .inline)
        .navigationBarItems(
            trailing: trailingNavigationItems
        )
    }

    private var saveButtonState: ConfigurationPageActionButtonState {
        if isSyncing {
            return .loading
        }

        let isEnabled = !scheduleItems.isEmpty
            && (scheduleItems != initialScheduleItems || mode == .acceptanceFlow)
            && tableDeletionState == .disabled

        return isEnabled ? .enabled : .disabled
    }

    private func itemView(for item: RepeatingScheduleValue<Value>, at index: Int) -> some View {
        Deletable(
            tableDeletionState: $tableDeletionState,
            index: index,
            isDeletable: index != 0,
            onDelete: {
                withAnimation {
                    self.scheduleItems.remove(at: index)

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
        .accessibility(identifier: "schedule_item_\(index)")
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
        Button(action: { self.dismiss() } ) { Text(LocalizedString("Cancel", comment: "Cancel editing settings button title")) }
    }

    var editButton: some View {
        Button(
            action: {
                withAnimation {
                    self.tableDeletionState = .enabled
                }
            },
            label: {
                Text(LocalizedString("Edit", comment: "Text for edit button"))
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
                Text(LocalizedString("Done", comment: "Text for done button")).bold()
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
        .disabled(tableDeletionState != .disabled || scheduleItems.count >= scheduleItemLimit)
    }

    private func startSaving() {
        guard mode == .settings else {
            self.continueSaving()
            return
        }
        
        authenticate(therapySettingType.authenticationChallengeDescription) {
            switch $0 {
            case .success: self.continueSaving()
            case .failure: break
            }
        }
    }
    
    private func continueSaving() {

        switch savingMechanism {
        case .synchronous(let save):
            save(scheduleItems)
        case .asynchronous(let save):
            withAnimation {
                self.editingIndex = nil
                self.isSyncing = true
            }

            save(scheduleItems) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        withAnimation {
                            self.isSyncing = false
                        }
                        self.presentedAlert = .saveError(error)
                    }
                }
            }
        }
    }

    private func alert(for presentedAlert: PresentedAlert) -> SwiftUI.Alert {
        switch presentedAlert {
        case .saveConfirmation(let content):
            return Alert(
                title: content.title,
                message: content.message,
                primaryButton: .cancel(Text(LocalizedString("Go Back", comment: "Button text to return to editing a schedule after from alert popup when some schedule values are outside the recommended range"))),
                secondaryButton: .default(
                    Text(LocalizedString("Continue", comment: "Button text to confirm saving from alert popup when some schedule values are outside the recommended range")),
                    action: startSaving
                )
            )
        case .saveError(let error):
            return Alert(
                title: Text(LocalizedString("Unable to Save", comment: "Alert title when error occurs while saving a schedule")),
                message: Text(error.localizedDescription)
            )
        }
    }
}

struct DarkenedOverlay: View {
    var body: some View {
        Rectangle()
            .fill(Color.black.opacity(0.3))
            .edgesIgnoringSafeArea(.all)
    }
}

extension ScheduleEditor.PresentedAlert: Identifiable {
    var id: Int {
        switch self {
        case .saveConfirmation:
            return 0
        case .saveError:
            return 1
        }
    }
}
