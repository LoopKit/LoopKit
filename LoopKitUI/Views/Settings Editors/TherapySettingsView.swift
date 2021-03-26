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

public struct TherapySettingsView: View {
    @EnvironmentObject private var displayGlucoseUnitObservable: DisplayGlucoseUnitObservable
    @Environment(\.dismiss) var dismiss
    @Environment(\.appName) private var appName

    public struct ActionButton {
        public init(localizedString: String, action: @escaping () -> Void) {
            self.localizedString = localizedString
            self.action = action
        }
        let localizedString: String
        let action: () -> Void
    }

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
        case .settings: return AnyView(navigationViewWrappedContent)
        }
    }
    
    private var content: some View {
        List {
            Group {
                if viewModel.mode == .acceptanceFlow && viewModel.prescription != nil {
                    // At start of acceptance flow
                    prescriptionSection
                } else if viewModel.mode == .acceptanceFlow && viewModel.prescription == nil {
                    // At end of acceptance flow
                    summaryHeaderSection
                }
                suspendThresholdSection
                correctionRangeSection
                preMealCorrectionRangeSection
                if !viewModel.sensitivityOverridesEnabled {
                    workoutCorrectionRangeSection
                }
                carbRatioSection
                basalRatesSection
                deliveryLimitsSection
                insulinModelSection
                insulinSensitivitiesSection
            }
            lastItem
        }
        .insetGroupedListStyle()
        .onAppear() {
            UITableView.appearance().separatorStyle = .singleLine // Add lines between rows
        }
        .navigationBarTitle(Text(LocalizedString("Therapy Settings", comment: "Therapy Settings screen title")), displayMode: .large)
    }
    
    private var navigationViewWrappedContent: some View {
        NavigationView {
            content
                .navigationBarItems(trailing: dismissButton)
        }
    }
    
    private var dismissButton: some View {
        Button(action: {
            self.dismiss()
        }) {
            Text(LocalizedString("Done", comment: "Text for dismiss button")).bold()
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
    
    private var summaryHeaderSection: some View {
        Section(header: Spacer()) {
            VStack(alignment: .leading) {
                Spacer()
                Text(LocalizedString("Review and Save Settings", comment: "title for summary description section"))
                    .bold()
                    .foregroundColor(.white)
                Spacer()
                VStack (alignment: .leading, spacing: 10) {
                    DescriptiveText(label: summaryHeaderReviewText, color: .white)
                    DescriptiveText(label: summaryHeaderEditText, color: .white)
                }
                Spacer()
            }
        }
        .listRowBackground(Color.accentColor)
    }
    
    private var summaryHeaderReviewText: String {
        String(format: LocalizedString("Review your therapy settings below. If you’d like to edit any of these settings, tap Back to go back to that screen.", comment: "Description of how to interact with summary screen"))
    }
    
    private var summaryHeaderEditText: String {
        String(format: LocalizedString("If these settings look good to you, tap Save Settings to continue.", comment: "Description of how to interact with summary screen"))
    }
    
    private var prescriptionDescriptiveText: String {
        String(format: LocalizedString("Submitted by %1$@, %2$@", comment: "Format for prescription descriptive text (1: providerName, 2: datePrescribed)"),
               viewModel.prescription!.providerName,
               DateFormatter.localizedString(from: viewModel.prescription!.datePrescribed, dateStyle: .short, timeStyle: .none))
    }
    
    private var suspendThresholdSection: some View {
        section(for: .suspendThreshold, header: viewModel.prescription == nil ? AnyView(Spacer()) : AnyView(EmptyView())) {
            HStack {
                Spacer()
                GuardrailConstrainedQuantityView(
                    value: self.viewModel.suspendThreshold?.quantity,
                    unit: glucoseUnit,
                    guardrail: .suspendThreshold,
                    isEditing: false,
                    // Workaround for strange animation behavior on appearance
                    forceDisableAnimations: true
                )
            }
        }
    }

    private var correctionRangeSection: some View {
        section(for: .glucoseTargetRange) {
            if let schedule = self.viewModel.glucoseTargetRangeSchedule(for: glucoseUnit)
            {
                ForEach(schedule.items, id: \.self) { value in
                    ScheduleRangeItem(time: value.startTime,
                                      range: value.value,
                                      unit: glucoseUnit,
                                      guardrail: .correctionRange)
                }
            }
        }
    }
    
    private var preMealCorrectionRangeSection: some View {
        section(for: .preMealCorrectionRangeOverride) {
            if let correctionRangeOverrides = self.viewModel.correctionRangeOverrides,
               let schedule = self.viewModel.glucoseTargetRangeSchedule
            {
                CorrectionRangeOverridesRangeItem(
                    value: correctionRangeOverrides,
                    displayGlucoseUnit: glucoseUnit,
                    preset: CorrectionRangeOverrides.Preset.preMeal,
                    suspendThreshold: viewModel.suspendThreshold,
                    correctionRangeScheduleRange: schedule.scheduleRange()
                )
            }
        }
    }
    
    private var workoutCorrectionRangeSection: some View {
        section(for: .workoutCorrectionRangeOverride) {
            if let correctionRangeOverrides = self.viewModel.correctionRangeOverrides,
               let schedule = self.viewModel.glucoseTargetRangeSchedule
            {
                CorrectionRangeOverridesRangeItem(
                    value: correctionRangeOverrides,
                    displayGlucoseUnit: glucoseUnit,
                    preset: CorrectionRangeOverrides.Preset.workout,
                    suspendThreshold: self.viewModel.suspendThreshold,
                    correctionRangeScheduleRange: schedule.scheduleRange()
                )
            }
        }
    }

    private var basalRatesSection: some View {
        section(for: .basalRate) {
            if self.viewModel.therapySettings.basalRateSchedule != nil && self.viewModel.pumpSupportedIncrements?() != nil {
                ForEach(self.viewModel.therapySettings.basalRateSchedule!.items, id: \.self) { value in
                    ScheduleValueItem(time: value.startTime,
                                      value: value.value,
                                      unit: .internationalUnitsPerHour,
                                      guardrail: .basalRate(supportedBasalRates: self.viewModel.pumpSupportedIncrements!()!.basalRates))
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
            if self.viewModel.pumpSupportedIncrements?() != nil {
                GuardrailConstrainedQuantityView(
                    value: self.viewModel.therapySettings.maximumBasalRatePerHour.map { HKQuantity(unit: .internationalUnitsPerHour, doubleValue: $0) },
                    unit: .internationalUnitsPerHour,
                    guardrail: .maximumBasalRate(
                        supportedBasalRates: self.viewModel.pumpSupportedIncrements!()!.basalRates,
                        scheduledBasalRange: self.viewModel.therapySettings.basalRateSchedule?.valueRange(),
                        lowestCarbRatio: self.viewModel.therapySettings.carbRatioSchedule?.lowestValue()),
                    isEditing: false,
                    // Workaround for strange animation behavior on appearance
                    forceDisableAnimations: true
                )
            }
        }
        .accessibilityElement(children: .combine)
    }
    
    private var maxBolusItem: some View {
        HStack {
            Text(DeliveryLimits.Setting.maximumBolus.title)
            Spacer()
            if self.viewModel.pumpSupportedIncrements?() != nil {
                GuardrailConstrainedQuantityView(
                    value: self.viewModel.therapySettings.maximumBolus.map { HKQuantity(unit: .internationalUnit(), doubleValue: $0) },
                    unit: .internationalUnit(),
                    guardrail: .maximumBolus(supportedBolusVolumes: self.viewModel.pumpSupportedIncrements!()!.bolusVolumes),
                    isEditing: false,
                    // Workaround for strange animation behavior on appearance
                    forceDisableAnimations: true
                )
            }
        }
        .accessibilityElement(children: .combine)
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
                .accessibilityElement(children: .combine)
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
                                      guardrail: .carbRatio)
                }
            }
        }
    }
    
    private var insulinSensitivitiesSection: some View {
        section(for: .insulinSensitivity) {
            if let schedule = viewModel.insulinSensitivitySchedule(for: glucoseUnit) {
                ForEach(schedule.items, id: \.self) { value in
                    ScheduleValueItem(time: value.startTime,
                                      value: value.value,
                                      unit: sensitivityUnit,
                                      guardrail: .insulinSensitivity)
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
    
    private var glucoseUnit: HKUnit {
        displayGlucoseUnitObservable.displayGlucoseUnit
    }
    
    private var sensitivityUnit: HKUnit {
        glucoseUnit.unitDivided(by: .internationalUnit())
    }
    
    private func section<Content>(for therapySetting: TherapySetting,
                                  @ViewBuilder content: @escaping () -> Content) -> some View where Content: View {
        SectionWithTapToEdit(isEnabled: viewModel.mode != .acceptanceFlow,
                             header: EmptyView(),
                             title: therapySetting.title,
                             descriptiveText: therapySetting.descriptiveText(appName: appName),
                             destination: viewModel.screen(for: therapySetting),
                             content: content)
    }

    private func section<Content, Header>(for therapySetting: TherapySetting,
                                          header: Header,
                                          @ViewBuilder content: @escaping () -> Content) -> some View where Content: View, Header: View {
        SectionWithTapToEdit(isEnabled: viewModel.mode != .acceptanceFlow,
                             header: header,
                             title: therapySetting.title,
                             descriptiveText: therapySetting.descriptiveText(appName: appName),
                             destination: viewModel.screen(for: therapySetting),
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
    let value: CorrectionRangeOverrides
    let displayGlucoseUnit: HKUnit
    let preset: CorrectionRangeOverrides.Preset
    let suspendThreshold: GlucoseThreshold?
    let correctionRangeScheduleRange: ClosedRange<HKQuantity>
    
    public var body: some View {
        CorrectionRangeOverridesExpandableSetting(
            isEditing: .constant(false),
            value: .constant(value),
            preset: preset,
            unit: displayGlucoseUnit,
            suspendThreshold: suspendThreshold,
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
    
    private func onFinish() {
        // Dispatching here fixes an issue on iOS 14.2 where schedule editors do not dismiss. It does not fix iOS 14.0 and 14.1
        DispatchQueue.main.async {
            self.isActive = false
        }
    }

    public var body: some View {
        Section(header: header) {
            VStack(alignment: .leading) {
                Spacer()
                Text(title)
                    .bold()
                Spacer()
                HStack {
                    DescriptiveText(label: descriptiveText)
                    if isEnabled {
                        Spacer()
                        NavigationLink(destination: destination(onFinish), isActive: $isActive) {
                            EmptyView()
                        }
                        .frame(width: 10, alignment: .trailing)
                    }
                }
                Spacer()
            }
            content()
        }
        .contentShape(Rectangle()) // make the whole card tappable
        .highPriorityGesture(
            TapGesture()
                .onEnded { _ in
                    self.isActive = true
        })
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
        correctionRangeOverrides: CorrectionRangeOverrides(preMeal: DoubleRange(88...99),
                                                           workout: DoubleRange(99...111),
                                                           unit: .milligramsPerDeciliter),
        maximumBolus: 4,
        suspendThreshold: GlucoseThreshold.init(unit: .milligramsPerDeciliter, value: 60),
        insulinSensitivitySchedule: InsulinSensitivitySchedule(unit: HKUnit.milligramsPerDeciliter.unitDivided(by: HKUnit.internationalUnit()), dailyItems: []),
        carbRatioSchedule: nil,
        basalRateSchedule: BasalRateSchedule(dailyItems: [RepeatingScheduleValue(startTime: 0, value: 0.2), RepeatingScheduleValue(startTime: 1800, value: 0.75)]))

    static let preview_supportedBasalRates = [0.2, 0.5, 0.75, 1.0]
    static let preview_supportedBolusVolumes = [5.0, 10.0, 15.0]

    static func preview_viewModel(mode: SettingsPresentationMode) -> TherapySettingsViewModel {
        TherapySettingsViewModel(mode: mode,
                                 therapySettings: preview_therapySettings,
                                 supportedInsulinModelSettings: SupportedInsulinModelSettings(fiaspModelEnabled: true, walshModelEnabled: true),
                                 pumpSupportedIncrements: { PumpSupportedIncrements(basalRates: preview_supportedBasalRates,
                                                                                  bolusVolumes: preview_supportedBolusVolumes,
                                                                                  maximumBasalScheduleEntryCount: 24) } ,
                                 chartColors: ChartColorPalette(axisLine: .clear, axisLabel: .secondaryLabel, grid: .systemGray3, glucoseTint: .systemTeal, insulinTint: .systemOrange))
    }

    public static var previews: some View {
        Group {
            TherapySettingsView(viewModel: preview_viewModel(mode: .acceptanceFlow))
                .colorScheme(.light)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
                .previewDisplayName("SE light (onboarding)")
                .environmentObject(DisplayGlucoseUnitObservable(displayGlucoseUnit: .milligramsPerDeciliter))
            TherapySettingsView(viewModel: preview_viewModel(mode: .settings))
                .colorScheme(.light)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
                .previewDisplayName("SE light (settings)")
                .environmentObject(DisplayGlucoseUnitObservable(displayGlucoseUnit: .milligramsPerDeciliter))
            TherapySettingsView(viewModel: preview_viewModel(mode: .settings))
                .colorScheme(.dark)
                .previewDevice(PreviewDevice(rawValue: "iPhone XS Max"))
                .previewDisplayName("XS Max dark (settings)")
            TherapySettingsView(viewModel: TherapySettingsViewModel(mode: .settings,
                                                                    therapySettings: TherapySettings(),
                                                                    chartColors: ChartColorPalette(axisLine: .clear,
                                                                                                   axisLabel: .secondaryLabel,
                                                                                                   grid: .systemGray3,
                                                                                                   glucoseTint: .systemTeal,
                                                                                                   insulinTint: .systemOrange)))
                .colorScheme(.light)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
                .previewDisplayName("SE light (Empty TherapySettings)")
                .environmentObject(DisplayGlucoseUnitObservable(displayGlucoseUnit: .millimolesPerLiter))
        }
    }
}
