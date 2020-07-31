//
//  TherapySettingsView.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 7/7/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import AVFoundation
import HealthKit
import LoopKit
import SwiftUI

public struct TherapySettingsView: View, HorizontalSizeClassOverride {
    public struct ActionButton {
        public init(localizedString: String, action: @escaping () -> Void) {
            self.localizedString = localizedString
            self.action = action
        }
        let localizedString: String
        let action: () -> Void
    }
    
    @Environment(\.dismiss) var dismiss
   
    @ObservedObject var viewModel: TherapySettingsViewModel
        
    private let actionButton: ActionButton?
        
    public init(viewModel: TherapySettingsViewModel,
                actionButton: ActionButton? = nil) {
        self.viewModel = viewModel
        self.actionButton = actionButton
    }
        
    public var body: some View {
        switch viewModel.mode {
        case .acceptanceFlow: return AnyView(content)
        case .settings: return AnyView(content)
        case .legacySettings: return AnyView(navigationViewWrappedContent)
        }
    }
    
    private var content: some View {
        List {
            Group {
                if viewModel.mode == .acceptanceFlow && viewModel.prescription != nil {
                    prescriptionSection
                }
                suspendThresholdSection
                correctionRangeSection
                temporaryCorrectionRangesSection
                basalRatesSection
                deliveryLimitsSection
                insulinModelSection
                carbRatioSection
                insulinSensitivitiesSection
            }
            lastItem
        }
        .listStyle(GroupedListStyle())
        .onAppear() {
            UITableView.appearance().separatorStyle = .singleLine // Add lines between rows
        }
        .navigationBarTitle(Text(LocalizedString("Therapy Settings", comment: "Therapy Settings screen title")), displayMode: .large)
        .environment(\.horizontalSizeClass, horizontalOverride)
    }
    
    private var navigationViewWrappedContent: some View {
        NavigationView {
            content
        }
    }
    
    @ViewBuilder private var lastItem: some View {
        if viewModel.mode == .acceptanceFlow {
            if actionButton != nil {
                Button(action: actionButton!.action) {
                    Text(actionButton!.localizedString)
                }
                .buttonStyle(ActionButtonStyle(.primary))
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
        } else {
            supportSection
        }
    }
}

// MARK: Sections
extension TherapySettingsView {
    
    private var prescriptionSection: some View {
        Section(header: Spacer()) {
            VStack(alignment: .leading) {
                Spacer()
                Text(LocalizedString("Prescription", comment: "title for prescription section"))
                    .bold()
                Spacer()
                DescriptiveText(label: prescriptionDescriptiveText)
                Spacer()
            }
        }
    }
    
    private var prescriptionDescriptiveText: String {
        String(format: LocalizedString("Submitted by %1$@, %2$@", comment: "Format for prescription descriptive text (1: providerName, 2: datePrescribed)"),
               viewModel.prescription!.providerName,
               DateFormatter.localizedString(from: viewModel.prescription!.datePrescribed, dateStyle: .short, timeStyle: .none))
    }
    
    private var correctionRangeSection: some View {
        section(for: .glucoseTargetRange) {
            if self.glucoseUnit != nil && self.viewModel.therapySettings.glucoseTargetRangeSchedule != nil {
                ForEach(self.viewModel.therapySettings.glucoseTargetRangeSchedule!.items, id: \.self) { value in
                    ScheduleRangeItem(time: value.startTime,
                                      range: value.value,
                                      unit: self.glucoseUnit!,
                                      guardrail: .correctionRange)
                }
            }
        }
    }
    
    private var temporaryCorrectionRangesSection: some View {
        section(for: .correctionRangeOverrides) {
            if self.glucoseUnit != nil && self.viewModel.therapySettings.glucoseTargetRangeSchedule != nil {
                ForEach(CorrectionRangeOverrides.Preset.allCases, id: \.self) { preset in
                    CorrectionRangeOverridesRangeItem(
                        preMealTargetRange: self.viewModel.therapySettings.preMealTargetRange,
                        workoutTargetRange: self.viewModel.therapySettings.workoutTargetRange,
                        unit: self.glucoseUnit!,
                        preset: preset,
                        correctionRangeScheduleRange: self.viewModel.therapySettings.glucoseTargetRangeSchedule!.scheduleRange()
                    )
                }
            }
        }
    }
    
    private var suspendThresholdSection: some View {
        section(for: .suspendThreshold, addExtraSpaceAboveSection: viewModel.prescription == nil) {
            if self.glucoseUnit != nil {
                HStack {
                    Spacer()
                    GuardrailConstrainedQuantityView(
                        value: self.viewModel.therapySettings.suspendThreshold?.quantity,
                        unit: self.glucoseUnit!,
                        guardrail: .suspendThreshold,
                        isEditing: false,
                        // Workaround for strange animation behavior on appearance
                        forceDisableAnimations: true
                    )
                }
            }
        }
    }
    
    private var basalRatesSection: some View {
        section(for: .basalRate) {
            if self.viewModel.therapySettings.basalRateSchedule != nil && self.viewModel.pumpSupportedIncrements != nil {
                ForEach(self.viewModel.therapySettings.basalRateSchedule!.items, id: \.self) { value in
                    ScheduleValueItem(time: value.startTime,
                                      value: value.value,
                                      unit: .internationalUnitsPerHour,
                                      guardrail: Guardrail.basalRate(supportedBasalRates: self.viewModel.pumpSupportedIncrements!.basalRates))
                }
            }
        }
    }
    
    private var deliveryLimitsSection: some View {
        section(for: .deliveryLimits) {
            self.maxBasalRateItem
            self.maxBolusItem
        }
    }
    
    private var maxBasalRateItem: some View {
        HStack {
            Text(DeliveryLimits.Setting.maximumBasalRate.title)
            Spacer()
            if self.viewModel.pumpSupportedIncrements != nil {
                GuardrailConstrainedQuantityView(
                    value: self.viewModel.therapySettings.maximumBasalRatePerHour.map { HKQuantity(unit: .internationalUnitsPerHour, doubleValue: $0) },
                    unit: .internationalUnitsPerHour,
                    guardrail: Guardrail.maximumBasalRate(supportedBasalRates: self.viewModel.pumpSupportedIncrements!.basalRates, scheduledBasalRange: self.viewModel.therapySettings.basalRateSchedule?.valueRange()),
                    isEditing: false,
                    // Workaround for strange animation behavior on appearance
                    forceDisableAnimations: true
                )
            }
        }
    }
    
    private var maxBolusItem: some View {
        HStack {
            Text(DeliveryLimits.Setting.maximumBolus.title)
            Spacer()
            if self.viewModel.pumpSupportedIncrements != nil {
                GuardrailConstrainedQuantityView(
                    value: self.viewModel.therapySettings.maximumBolus.map { HKQuantity(unit: .internationalUnit(), doubleValue: $0) },
                    unit: .internationalUnit(),
                    guardrail: Guardrail.maximumBolus(supportedBolusVolumes: self.viewModel.pumpSupportedIncrements!.bolusVolumes),
                    isEditing: false,
                    // Workaround for strange animation behavior on appearance
                    forceDisableAnimations: true
                )
            }
        }
    }
        
    private var insulinModelSection: some View {
        section(for: .insulinModel) {
            if self.viewModel.therapySettings.insulinModelSettings != nil {
                // Spacing and paddings here is my best guess based on the design...
                VStack(alignment: .leading, spacing: 4) {
                    Text(self.viewModel.therapySettings.insulinModelSettings!.title)
                        .font(.body)
                        .padding(.top, 5)
                    Text(self.viewModel.therapySettings.insulinModelSettings!.subtitle)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                }
            }
        }
    }

    private var carbRatioSection: some View {
        section(for: .carbRatio) {
            if self.viewModel.therapySettings.carbRatioSchedule != nil {
                ForEach(self.viewModel.therapySettings.carbRatioSchedule!.items, id: \.self) { value in
                    ScheduleValueItem(time: value.startTime,
                                      value: value.value,
                                      unit: .gramsPerUnit,
                                      guardrail: Guardrail.carbRatio)
                }
            }
        }
    }
    
    private var insulinSensitivitiesSection: some View {
        section(for: .insulinSensitivity) {
            if self.viewModel.therapySettings.insulinSensitivitySchedule != nil && self.sensitivityUnit != nil {
                ForEach(self.viewModel.therapySettings.insulinSensitivitySchedule!.items, id: \.self) { value in
                    ScheduleValueItem(time: value.startTime,
                                      value: value.value,
                                      unit: self.sensitivityUnit!,
                                      guardrail: Guardrail.insulinSensitivity)
                }
            }
        }
    }
    
    private var supportSection: some View {
        Section(header: SectionHeader(label: LocalizedString("Support", comment: "Title for support section"))) {
            NavigationLink(destination: Text("Therapy Settings Support Placeholder")) {
                Text("Get help with Therapy Settings", comment: "Support button for Therapy Settings")
            }
        }
    }
}

// MARK: Utilities
extension TherapySettingsView {
    
    private var glucoseUnit: HKUnit? {
        viewModel.therapySettings.glucoseTargetRangeSchedule?.unit
    }
    
    private var sensitivityUnit: HKUnit? {
        glucoseUnit?.unitDivided(by: .internationalUnit())
    }

    private func section<Content>(for therapySetting: TherapySetting,
                                  addExtraSpaceAboveSection: Bool = false,
                                  @ViewBuilder content: @escaping () -> Content) -> some View where Content: View {
        SectionWithTapToEdit(isEnabled: viewModel.mode != .acceptanceFlow,
                             header: addExtraSpaceAboveSection ? AnyView(Spacer()) : AnyView(EmptyView()),
                             title: therapySetting.title,
                             descriptiveText: therapySetting.descriptiveText,
                             destination: screen(for: therapySetting),
                             content: content)
    }
}

typealias HKQuantityGuardrail = Guardrail<HKQuantity>

struct ScheduleRangeItem: View {
    let time: TimeInterval
    let range: DoubleRange
    let unit: HKUnit
    let guardrail: HKQuantityGuardrail
    
    public var body: some View {
        ScheduleItemView(time: time,
                         isEditing: .constant(false),
                         valueContent: {
                            GuardrailConstrainedQuantityRangeView(range: range.quantityRange(for: unit), unit: unit, guardrail: guardrail, isEditing: false)
                         },
                         expandedContent: { EmptyView() })
    }
}

struct ScheduleValueItem: View {
    let time: TimeInterval
    let value: Double
    let unit: HKUnit
    let guardrail: HKQuantityGuardrail
    
    public var body: some View {
        ScheduleItemView(time: time,
                         isEditing: .constant(false),
                         valueContent: {
                            GuardrailConstrainedQuantityView(value: HKQuantity(unit: unit, doubleValue: value), unit: unit, guardrail: guardrail, isEditing: false)
                         },
                         expandedContent: { EmptyView() })
    }
}

struct CorrectionRangeOverridesRangeItem: View {
    let preMealTargetRange: DoubleRange?
    let workoutTargetRange: DoubleRange?
    let unit: HKUnit
    let preset: CorrectionRangeOverrides.Preset
    let correctionRangeScheduleRange: ClosedRange<HKQuantity>
    
    public var body: some View {
        CorrectionRangeOverridesExpandableSetting(
            isEditing: .constant(false),
            value: .constant(CorrectionRangeOverrides(
                preMeal: preMealTargetRange,
                workout: workoutTargetRange,
                unit: unit
            )),
            preset: preset,
            unit: unit,
            correctionRangeScheduleRange: correctionRangeScheduleRange,
            expandedContent: { EmptyView() })
    }
}

struct SectionWithTapToEdit<Header, Content, NavigationDestination>: View where Header: View, Content: View, NavigationDestination: View  {
    let isEnabled: Bool
    let header: Header
    let title: String
    let descriptiveText: String
    let destination: (_ goBack: @escaping () -> Void) -> NavigationDestination
    let content: () -> Content

    @State var isActive: Bool = false
    
    public var body: some View {
        Section(header: header) {
            VStack(alignment: .leading) {
                Spacer()
                Text(title)
                    .bold()
                Spacer()
                ZStack(alignment: .leading) {
                    DescriptiveText(label: descriptiveText)
                    if isEnabled {
                        NavigationLink(destination: destination({ self.isActive = false }), isActive: $isActive) {
                            EmptyView()
                        }
                    }
                }
                Spacer()
            }
            content()
        }
        .highPriorityGesture(
            TapGesture()
                .onEnded { _ in
                    self.isActive = true
        })
    }
}

// MARK: Navigation

private extension TherapySettingsView {
    
    func screen(for setting: TherapySetting) -> (_ goBack: @escaping () -> Void) -> AnyView {
        switch setting {
        case .glucoseTargetRange:
            if viewModel.therapySettings.glucoseUnit != nil {
                return { goBack in
                    AnyView(CorrectionRangeScheduleEditor(
                        schedule: self.viewModel.therapySettings.glucoseTargetRangeSchedule,
                        unit: self.viewModel.therapySettings.glucoseUnit!,
                        minValue: self.viewModel.therapySettings.suspendThreshold?.quantity,
                        onSave: { newSchedule in
                            self.viewModel.saveCorrectionRange(range: newSchedule)
                            goBack()
                        },
                        mode: self.viewModel.mode))
                }
            }
        case .correctionRangeOverrides:
            if self.viewModel.therapySettings.glucoseUnit != nil {
                return { goBack in
                   AnyView(CorrectionRangeOverridesEditor(
                        value: CorrectionRangeOverrides(
                            preMeal: self.viewModel.therapySettings.preMealTargetRange,
                            workout: self.viewModel.therapySettings.workoutTargetRange,
                            unit: self.viewModel.therapySettings.glucoseUnit!
                        ),
                        unit: self.viewModel.therapySettings.glucoseUnit!,
                        correctionRangeScheduleRange: self.viewModel.therapySettings.glucoseTargetRangeSchedule!.scheduleRange(),
                        minValue: self.viewModel.therapySettings.suspendThreshold?.quantity,
                        onSave: { overrides in
                            self.viewModel.saveCorrectionRangeOverrides(overrides: overrides, unit: self.viewModel.therapySettings.glucoseUnit!)
                            goBack()
                        },
                        sensitivityOverridesEnabled: self.viewModel.sensitivityOverridesEnabled,
                        mode: self.viewModel.mode
                    ))
                }
            }
        case .suspendThreshold:
            if viewModel.therapySettings.glucoseUnit != nil {
                return { goBack in
                    AnyView(SuspendThresholdEditor(
                        value: self.viewModel.therapySettings.suspendThreshold?.quantity,
                        unit: self.viewModel.therapySettings.glucoseUnit!,
                        maxValue: Guardrail.maxSuspendThresholdValue(
                            correctionRangeSchedule: self.viewModel.therapySettings.glucoseTargetRangeSchedule,
                            preMealTargetRange: self.viewModel.therapySettings.preMealTargetRange,
                            workoutTargetRange: self.viewModel.therapySettings.workoutTargetRange,
                            unit: self.viewModel.therapySettings.glucoseUnit!
                        ),
                        onSave: { newValue in
                            self.viewModel.saveSuspendThreshold(value: GlucoseThreshold(unit: self.viewModel.therapySettings.glucoseUnit!, value: newValue.doubleValue(for: self.viewModel.therapySettings.glucoseUnit!)))
                            goBack()
                        },
                        mode: self.viewModel.mode
                    ))
                }
            }
        case .basalRate:
            if self.viewModel.pumpSupportedIncrements != nil {
                return { goBack in
                    AnyView(BasalRateScheduleEditor(
                        schedule: self.viewModel.therapySettings.basalRateSchedule,
                        supportedBasalRates: self.viewModel.pumpSupportedIncrements!.basalRates ,
                        maximumBasalRate: self.viewModel.therapySettings.maximumBasalRatePerHour,
                        maximumScheduleEntryCount: self.viewModel.pumpSupportedIncrements!.maximumBasalScheduleEntryCount,
                        syncSchedule: self.viewModel.syncPumpSchedule,
                        onSave: { newRates in
                            self.viewModel.saveBasalRates(basalRates: newRates)
                            goBack()
                        },
                        mode: self.viewModel.mode
                    ))
                }
            }
        case .deliveryLimits:
            if self.viewModel.pumpSupportedIncrements != nil {
                return { goBack in
                    AnyView(DeliveryLimitsEditor(
                        value: self.viewModel.deliveryLimits,
                        supportedBasalRates: self.viewModel.pumpSupportedIncrements!.basalRates,
                        scheduledBasalRange: self.viewModel.therapySettings.basalRateSchedule?.valueRange(),
                        supportedBolusVolumes: self.viewModel.pumpSupportedIncrements!.bolusVolumes,
                        onSave: { limits in
                            self.viewModel.saveDeliveryLimits(limits: limits)
                            goBack()
                        },
                        mode: self.viewModel.mode
                    ))
                }
            }
        case .insulinModel:
            if self.viewModel.therapySettings.glucoseUnit != nil && self.viewModel.therapySettings.insulinModelSettings != nil {
                return { goBack in
                    AnyView(InsulinModelSelection(value: self.viewModel.therapySettings.insulinModelSettings!,
                                                  insulinSensitivitySchedule: self.viewModel.therapySettings.insulinSensitivitySchedule,
                                                  glucoseUnit: self.viewModel.therapySettings.glucoseUnit!,
                                                  supportedModelSettings: self.viewModel.supportedInsulinModelSettings,
                                                  mode: self.viewModel.mode,
                                                  onSave: { insulinModelSettings in
                                                      self.viewModel.saveInsulinModel(insulinModelSettings: insulinModelSettings)
                                                      goBack()
                                                  }
                    ))
                }
            }
        case .carbRatio:
            return { goBack in
                AnyView(CarbRatioScheduleEditor(
                    schedule: self.viewModel.therapySettings.carbRatioSchedule,
                    mode: self.viewModel.mode,
                    onSave: {
                        self.viewModel.saveCarbRatioSchedule(carbRatioSchedule: $0)
                        goBack()
                    }
                ))
            }
        case .insulinSensitivity:
            if self.viewModel.therapySettings.glucoseUnit != nil {
                return { goBack in
                    return AnyView(InsulinSensitivityScheduleEditor(
                        schedule: self.viewModel.therapySettings.insulinSensitivitySchedule,
                        mode: self.viewModel.mode,
                        glucoseUnit: self.viewModel.therapySettings.glucoseUnit!,
                        onSave: {
                            self.viewModel.saveInsulinSensitivitySchedule(insulinSensitivitySchedule: $0)
                            goBack()
                        }
                    ))
                }
            }
        case .none:
            break
        }
        return { _ in AnyView(Text("\(setting.title)")) }
    }
}

// MARK: Previews

public struct TherapySettingsView_Previews: PreviewProvider {

    static let preview_glucoseScheduleItems = [
        RepeatingScheduleValue(startTime: 0, value: DoubleRange(80...90)),
        RepeatingScheduleValue(startTime: 1800, value: DoubleRange(90...100)),
        RepeatingScheduleValue(startTime: 3600, value: DoubleRange(100...110))
    ]

    static let preview_therapySettings = TherapySettings(
        glucoseTargetRangeSchedule: GlucoseRangeSchedule(unit: .milligramsPerDeciliter, dailyItems: preview_glucoseScheduleItems),
        preMealTargetRange: DoubleRange(88...99),
        workoutTargetRange: DoubleRange(99...111),
        maximumBasalRatePerHour: 55,
        maximumBolus: 4,
        suspendThreshold: GlucoseThreshold.init(unit: .milligramsPerDeciliter, value: 60),
        insulinSensitivitySchedule: InsulinSensitivitySchedule(unit: HKUnit.milligramsPerDeciliter.unitDivided(by: HKUnit.internationalUnit()), dailyItems: []),
        carbRatioSchedule: nil,
        basalRateSchedule: BasalRateSchedule(dailyItems: [RepeatingScheduleValue(startTime: 0, value: 0.2), RepeatingScheduleValue(startTime: 1800, value: 0.75)]))

    static let preview_supportedBasalRates = [0.2, 0.5, 0.75, 1.0]
    static let preview_supportedBolusVolumes = [5.0, 10.0, 15.0]

    static func preview_viewModel(mode: PresentationMode) -> TherapySettingsViewModel {
        TherapySettingsViewModel(mode: mode,
                                 therapySettings: preview_therapySettings,
                                 supportedInsulinModelSettings: SupportedInsulinModelSettings(fiaspModelEnabled: true, walshModelEnabled: true),
                                 pumpSupportedIncrements: PumpSupportedIncrements(basalRates: preview_supportedBasalRates,
                                                                                  bolusVolumes: preview_supportedBolusVolumes,
                                                                                  maximumBasalScheduleEntryCount: 24))
    }

    public static var previews: some View {
        Group {
            TherapySettingsView(viewModel: preview_viewModel(mode: .acceptanceFlow))
                .colorScheme(.light)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
                .previewDisplayName("SE light (onboarding)")
            TherapySettingsView(viewModel: preview_viewModel(mode: .settings))
                .colorScheme(.light)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
                .previewDisplayName("SE light (settings)")
            TherapySettingsView(viewModel: preview_viewModel(mode: .settings))
                .colorScheme(.dark)
                .previewDevice(PreviewDevice(rawValue: "iPhone XS Max"))
                .previewDisplayName("XS Max dark (settings)")
            TherapySettingsView(viewModel: TherapySettingsViewModel(mode: .legacySettings, therapySettings: TherapySettings()))
                .colorScheme(.light)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
                .previewDisplayName("SE light (Empty TherapySettings)")
        }
    }
}
