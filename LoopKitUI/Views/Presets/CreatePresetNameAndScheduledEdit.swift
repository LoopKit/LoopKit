//
//  CreatePresetNameAndScheduledEdit.swift
//  Loop
//
//  Created by Pete Schwamb on 3/5/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//


import LoopKit
import SwiftUI

public enum RepeatOption: CaseIterable {
    case never
    case weekly
}

extension RepeatOption: CustomStringConvertible {
    public var description: String {
        switch self {
        case .never:
            NSLocalizedString(
                "Never",
                comment: "Repeat option never for a preset schedule"
            )
        case .weekly:
            NSLocalizedString(
                "Weekly",
                comment: "Repeat option weekly for a preset schedule"
            )
        }
    }
}

struct CreatePresetNameAndScheduledEdit: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var preset: NewCustomPreset
    @Binding var path: NavigationPath
    
    @State private var isDurationPickerExpanded = false

    @FocusState private var isTextFieldFocused: Bool

    @State private var selectedRepeatOption: RepeatOption
    @State private var showingDayPicker: Bool = false

    var onCancel: () -> Void

    init(
        preset: Binding<NewCustomPreset>,
        path: Binding<NavigationPath>,
        isDurationPickerExpanded: Bool = false,
        onCancel: @escaping () -> Void
    ) {
        self._preset = preset
        self._path = path
        self._isDurationPickerExpanded = State(initialValue: isDurationPickerExpanded)
        self._selectedRepeatOption = State(initialValue: preset.wrappedValue.repeatOptions == .none ? .never : .weekly)
        self.onCancel = onCancel
    }

    var body: some View {
        CardSectionScrollView {
            CardSection {
                // Save Preset Toggle
                HStack {
                    Text("Save Preset")
                        .font(.body)

                    Spacer()

                    Toggle("", isOn: $preset.savePreset.animation())
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                        .labelsHidden()
                        .padding(.vertical, -6)
                }
            }

            Text("Toggle off for a single use preset")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)

            // Name Field
            if preset.savePreset {
                CardSection {
                    HStack {
                        Text("Name")
                            .font(.body)

                        Spacer()

                        TextField("", text: $preset.name, prompt: Text("Required"))
                            .multilineTextAlignment(.trailing)
                            .focused($isTextFieldFocused)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Duration Section
            CardSection {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Duration")
                            .foregroundColor(.primary)
                        Spacer()
                        Group {
                            if let duration = preset.duration {
                                Text(duration.localizedTitle)
                                Image(systemName: "chevron.right")
                            } else {
                                Text("Required")
                                    .foregroundStyle(.placeholder)
                            }
                        }
                        .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isTextFieldFocused = false
                        withAnimation() {
                            isDurationPickerExpanded.toggle()
                        }
                    }

                    if isDurationPickerExpanded {
                        DurationPickerView(
                            durationType: Binding(
                                get: {
                                    return preset.duration ?? .duration(.hours(1))
                                },
                                set: { duration in
                                    preset.duration = duration
                                }
                            )
                        )
                    }
                }
            }

            // Schedule Toggle
            if preset.savePreset {
                CardSection {
                    HStack {
                        Text("Schedule")
                            .font(.body)

                        Spacer()

                        Toggle("", isOn: Binding(get: {
                            return preset.startDate != nil
                        }, set: { newValue in
                            withAnimation {
                                if newValue {
                                    preset.startDate = Date().addingTimeInterval(.hours(1))
                                } else {
                                    preset.startDate = nil
                                    preset.repeatOptions = .none
                                }
                            }
                        }))
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                        .labelsHidden()
                        .padding(.vertical, -4)
                    }

                    if preset.startDate != nil {
                        Divider()
                        HStack {
                            if selectedRepeatOption == .never {
                                Text("Date")
                            } else {
                                Text("Start Date")
                            }
                            Spacer()
                            DatePicker(
                                "",
                                selection: Binding(get: {
                                    preset.startDate ?? Date()
                                }, set: { newValue in
                                    preset.startDate = newValue
                                }),
                                in: Date()...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                        }
                        Divider()
                            .padding(.top, -4)
                        HStack {
                            Text("Repeat")
                            Spacer()
                            Picker("Repeat", selection: $selectedRepeatOption.animation()) {
                                ForEach(RepeatOption.allCases, id: \.self) { option in
                                    Text(String(describing: option))
                                }
                            }
                            .tint(.secondary)
                            .pickerStyle(MenuPickerStyle())
                            .padding(.trailing, -8)
                        }

                        if selectedRepeatOption == .weekly {
                            Divider()
                                .padding(.top, -4)
                            HStack {
                                Text("Selected days")
                                    .foregroundColor(.primary)
                                HStack {
                                    Spacer()
                                    RepeatOptionView(repeatOptions: preset.repeatOptions)
                                        .padding(.vertical, 6)
                                        .onTapGesture {
                                            withAnimation {
                                                showingDayPicker = true
                                            }
                                        }
                                }
                                .popover(isPresented: $showingDayPicker, arrowEdge: .bottom) {
                                    DayPickerPopup(selectedDays: Binding(
                                        get: {
                                            preset.repeatOptions
                                        }, set: { newValue in
                                            preset.repeatOptions = newValue.union(requiredRepeatOption ?? .none)
                                        }))
                                    .cornerRadius(12)
                                    .presentationCompactAdaptation(.popover)
                                }
                            }
                        }
                    }
                }
                if preset.repeatOptions != .none {
                    Text(preset.scheduleDescription())
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.top, 4)
                }
            }
        } actionArea: {
            Button("Continue") {
                path.append(CreatePresetPage.summary)
            }
            .disabled(!allowSave)
            .buttonStyle(ActionButtonStyle(.primary))
        }
        .onChange(of: selectedRepeatOption, { oldValue, newValue in
            if newValue == .weekly {
                assignRepeatDays()
            }
            if newValue == .never {
                preset.repeatOptions = .none
            }
        })
        .onChange(of: preset.startDate, { oldValue, newValue in
            if newValue != nil {
                assignRepeatDays()
            }
        })
        .animation(.easeInOut, value: preset.duration)

        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Create a Preset")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cancel") {
                    onCancel()
                }
            }
        }
    }

    private var requiredRepeatOption: PresetScheduleRepeatOptions? {
        guard let startDate = preset.startDate else { return nil }
        guard selectedRepeatOption == .weekly else { return nil }
        return .allCases[Calendar.current.component(.weekday, from: startDate) - 1]
    }

    func assignRepeatDays() {
        guard let requiredRepeatOption else {
            return
        }
        preset.repeatOptions = requiredRepeatOption
    }

    var allowSave: Bool {
        return (!preset.savePreset && preset.duration != nil) || (preset.savePreset && !preset.name.isEmpty && preset.duration != nil)
    }
}

// Preview Provider
struct PresetCreationView_Previews: PreviewProvider {
    @State static var preset: NewCustomPreset = .init()
    @State static var path: NavigationPath = .init()

    static var previews: some View {
        CreatePresetNameAndScheduledEdit(preset: $preset, path: $path, onCancel: {})
    }
}
