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
    @Environment(\.chartColorPalette) var chartColorPalette
    @Environment(\.dismissAction) var dismissAction
    @Environment(\.appName) private var appName

    public struct ActionButton {
        public init(localizedString: String, action: @escaping () -> Void) {
            self.localizedString = localizedString
            self.action = action
        }
        let localizedString: String
        let action: () -> Void
    }

    private let mode: SettingsPresentationMode

    @ObservedObject var viewModel: TherapySettingsViewModel
        
    private let actionButton: ActionButton?

    public init(mode: SettingsPresentationMode,
                viewModel: TherapySettingsViewModel,
                actionButton: ActionButton? = nil) {
        self.mode = mode
        self.viewModel = viewModel
        self.actionButton = actionButton
    }
        
    public var body: some View {
        switch mode {
        case .acceptanceFlow:
            content
        case .settings:
            navigationViewWrappedContent
        }
    }
    
    private var content: some View {
        CardList(title: cardListTitle, style: .sectioned(cardListSections), trailer: cardListTrailer)
    }

    private var cardListTitle: Text? { mode == .acceptanceFlow ? Text(therapySettingsTitle) : nil }

    private var therapySettingsTitle: String {
        return LocalizedString("Therapy Settings", comment: "Therapy Settings screen title")
    }

    private var cardListSections: [CardListSection] {
        var cardListSections: [CardListSection] = []

        cardListSections.append(therapySettingsCardListSection)
        if mode == .settings {
            cardListSections.append(supportCardListSection)
        }

        return cardListSections
    }
    
    private var therapySettingsCardListSection: CardListSection {
        CardListSection {
            therapySettingsCardStack
                .spacing(20)
        }
    }

    private var therapySettingsCardStack: CardStack {
        var cards: [Card] = []

        if mode == .acceptanceFlow {
            if viewModel.prescription != nil {
                cards.append(prescriptionSection)
            } else {
                cards.append(summaryHeaderSection)
            }
        }
        cards.append(suspendThresholdSection)
        cards.append(correctionRangeSection)
        cards.append(preMealCorrectionRangeSection)
        if !viewModel.sensitivityOverridesEnabled {
            cards.append(workoutCorrectionRangeSection)
        }
        cards.append(carbRatioSection)
        cards.append(basalRatesSection)
        cards.append(deliveryLimitsSection)
        if viewModel.adultChildInsulinModelSelectionEnabled {
            cards.append(insulinModelSection)
        }
        cards.append(insulinSensitivitiesSection)

        return CardStack(cards: cards)
    }
    
    private var supportCardListSection: CardListSection {
        CardListSection(title: Text(LocalizedString("Support", comment: "Title for support section"))) {
            supportSection
        }
    }

    private var navigationViewWrappedContent: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                content
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            dismissButton
                        }
                    }
                    .navigationBarTitle(therapySettingsTitle, displayMode: .large)
            }
        }
    }
    
    private var dismissButton: some View {
        Button(action: dismissAction) {
            Text(LocalizedString("Done", comment: "Text for dismiss button"))
                .bold()
        }
    }
    
    @ViewBuilder
    private var cardListTrailer: some View {
        if mode == .acceptanceFlow {
            if let actionButton = actionButton {
                Button(action: actionButton.action) {
                    Text(actionButton.localizedString)
                }
                .buttonStyle(ActionButtonStyle(.primary))
                .padding()
            }
        }
    }
}

// MARK: Sections
extension TherapySettingsView {
    
    private var prescriptionSection: Card {
        Card {
            HStack {
                VStack(alignment: .leading) {
                    Text(LocalizedString("Prescription", comment: "title for prescription section"))
                        .bold()
                    Spacer()
                    DescriptiveText(label: prescriptionDescriptiveText)
                }
                Spacer()
            }
        }
    }
    
    private var summaryHeaderSection: Card {
        Card {
            VStack(alignment: .leading) {
                Text(LocalizedString("Review and Save Settings", comment: "title for summary description section"))
                    .bold()
                    .foregroundColor(.white)
                Spacer()
                VStack (alignment: .leading, spacing: 10) {
                    DescriptiveText(label: summaryHeaderReviewText, color: .white)
                        .fixedSize(horizontal: false, vertical: true)
                    DescriptiveText(label: summaryHeaderEditText, color: .white)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .backgroundColor(Color.accentColor)
    }
    
    private var summaryHeaderReviewText: String {
        String(format: LocalizedString("Review your therapy settings below. If you’d like to edit any of these settings, tap Back to go back to that screen.", comment: "Description of how to interact with summary screen"))
    }
    
    private var summaryHeaderEditText: String {
        String(format: LocalizedString("If these settings look good to you, tap Save Settings to continue.", comment: "Description of how to interact with summary screen"))
    }
    
    private var prescriptionDescriptiveText: String {
        guard let prescription = viewModel.prescription else {
            return ""
        }
        return String(format: LocalizedString("Submitted by %1$@, %2$@", comment: "Format for prescription descriptive text (1: providerName, 2: datePrescribed)"),
                      prescription.providerName,
                      DateFormatter.localizedString(from: prescription.datePrescribed, dateStyle: .short, timeStyle: .none))
    }

    private var suspendThresholdSection: Card {
        card(for: .suspendThreshold) {
            SectionDivider()
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

    private var correctionRangeSection: Card {
        card(for: .glucoseTargetRange) {
            if let items = self.viewModel.glucoseTargetRangeSchedule(for: glucoseUnit)?.items
            {
                SectionDivider()
                ForEach(items.indices, id: \.self) { index in
                    if index > 0 {
                        SettingsDivider()
                    }
                    ScheduleRangeItem(time: items[index].startTime,
                                      range: items[index].value,
                                      unit: glucoseUnit,
                                      guardrail: .correctionRange)
                }
            }
        }
    }
    
    private var preMealCorrectionRangeSection: Card {
        card(for: .preMealCorrectionRangeOverride) {
            if let correctionRangeOverrides = self.viewModel.correctionRangeOverrides,
               let schedule = self.viewModel.glucoseTargetRangeSchedule
            {
                SectionDivider()
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
    
    private var workoutCorrectionRangeSection: Card {
        card(for: .workoutCorrectionRangeOverride) {
            if let correctionRangeOverrides = self.viewModel.correctionRangeOverrides,
               let schedule = self.viewModel.glucoseTargetRangeSchedule
            {
                SectionDivider()
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

    private var basalRatesSection: Card {
        card(for: .basalRate) {
            if let schedule = viewModel.therapySettings.basalRateSchedule,
               let supportedBasalRates = viewModel.pumpSupportedIncrements()?.basalRates
            {
                let items = schedule.items
                let total = schedule.total()
                SectionDivider()
                ForEach(items.indices, id: \.self) { index in
                    if index > 0 {
                        SettingsDivider()
                    }
                    ScheduleValueItem(time: items[index].startTime,
                                      value:  items[index].value,
                                      unit: .internationalUnitsPerHour,
                                      guardrail: .basalRate(supportedBasalRates: supportedBasalRates))
                }
                SectionDivider()
                HStack {
                    Text(NSLocalizedString("Total", comment: "The text indicating Total for Daily Schedule Basal"))
                        .bold()
                        .foregroundColor(.primary)
                    Spacer()
                    Text(String(format: "%.2f ",total))
                        .foregroundColor(.primary) +
                    Text(NSLocalizedString("U/day", comment: "The text indicating U/day for Daily Schedule Basal"))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var deliveryLimitsSection: Card {
        card(for: .deliveryLimits) {
            SectionDivider()
            self.maxBasalRateItem
            SettingsDivider()
            self.maxBolusItem
        }
    }
    
    private var maxBasalRateItem: some View {
        HStack {
            Text(DeliveryLimits.Setting.maximumBasalRate.title)
            Spacer()
            if let basalRates = self.viewModel.pumpSupportedIncrements()?.basalRates {
                GuardrailConstrainedQuantityView(
                    value: self.viewModel.therapySettings.maximumBasalRatePerHour.map { HKQuantity(unit: .internationalUnitsPerHour, doubleValue: $0) },
                    unit: .internationalUnitsPerHour,
                    guardrail: .maximumBasalRate(
                        supportedBasalRates: basalRates,
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
            if let maximumBolusVolumes = self.viewModel.pumpSupportedIncrements()?.maximumBolusVolumes {
                GuardrailConstrainedQuantityView(
                    value: self.viewModel.therapySettings.maximumBolus.map { HKQuantity(unit: .internationalUnit(), doubleValue: $0) },
                    unit: .internationalUnit(),
                    guardrail: .maximumBolus(supportedBolusVolumes: maximumBolusVolumes),
                    isEditing: false,
                    // Workaround for strange animation behavior on appearance
                    forceDisableAnimations: true
                )
            }
        }
        .accessibilityElement(children: .combine)
    }
        
    private var insulinModelSection: Card {
        card(for: .insulinModel) {
            if let insulinModelPreset = self.viewModel.therapySettings.defaultRapidActingModel {
                SectionDivider()
                HStack {
                    // Spacing and paddings here is my best guess based on the design...
                    VStack(alignment: .leading, spacing: 4) {
                        Text(insulinModelPreset.title)
                            .font(.body)
                            .padding(.top, 5)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(insulinModelPreset.subtitle)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "checkmark")
                        .font(Font.system(.title2).weight(.semibold))
                        .foregroundColor(.accentColor)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var carbRatioSection: Card {
        card(for: .carbRatio) {
            if let items = viewModel.therapySettings.carbRatioSchedule?.items {
                SectionDivider()
                ForEach(items.indices, id: \.self) { index in
                    if index > 0 {
                        SettingsDivider()
                    }
                    ScheduleValueItem(time: items[index].startTime,
                                      value: items[index].value,
                                      unit: .gramsPerUnit,
                                      guardrail: .carbRatio)
                }
            }
        }
    }
    
    private var insulinSensitivitiesSection: Card {
        card(for: .insulinSensitivity) {
            if let items = viewModel.insulinSensitivitySchedule(for: glucoseUnit)?.items {
                SectionDivider()
                ForEach(items.indices, id: \.self) { index in
                    if index > 0 {
                        SettingsDivider()
                    }
                    ScheduleValueItem(time: items[index].startTime,
                                      value: items[index].value,
                                      unit: sensitivityUnit,
                                      guardrail: .insulinSensitivity)
                }
            }
        }
    }
    
    private var supportSection: some View {
        Section {
            NavigationLink(destination: Text("Therapy Settings Support Placeholder")) {
                HStack {
                    Text("Get help with Therapy Settings", comment: "Support button for Therapy Settings")
                        .foregroundColor(.primary)
                    Spacer()
                    Disclosure()
                }
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: Navigation

extension TherapySettingsView {

    func screen(for setting: TherapySetting) -> (_ dismiss: @escaping () -> Void) -> AnyView {
        switch setting {
        case .suspendThreshold:
            return { dismiss in
                AnyView(SuspendThresholdEditor(mode: mode, therapySettingsViewModel: viewModel, didSave: dismiss).environment(\.dismissAction, dismiss))
            }
        case .glucoseTargetRange:
            return { dismiss in
                AnyView(CorrectionRangeScheduleEditor(mode: mode, therapySettingsViewModel: viewModel, didSave: dismiss).environment(\.dismissAction, dismiss))
            }
        case .preMealCorrectionRangeOverride:
            return { dismiss in
                AnyView(CorrectionRangeOverridesEditor(mode: mode, therapySettingsViewModel: viewModel, preset: .preMeal, didSave: dismiss).environment(\.dismissAction, dismiss))
            }
        case .workoutCorrectionRangeOverride:
            return { dismiss in
                AnyView(CorrectionRangeOverridesEditor(mode: mode, therapySettingsViewModel: viewModel, preset: .workout, didSave: dismiss).environment(\.dismissAction, dismiss))
            }
        case .basalRate:
            return { dismiss in
                AnyView(BasalRateScheduleEditor(mode: mode, therapySettingsViewModel: viewModel, didSave: dismiss).environment(\.dismissAction, dismiss))
            }
        case .deliveryLimits:
            return { dismiss in
                AnyView(DeliveryLimitsEditor(mode: mode, therapySettingsViewModel: viewModel, didSave: dismiss).environment(\.dismissAction, dismiss))
            }
        case .insulinModel:
            return { dismiss in
                AnyView(InsulinModelSelection(mode: mode, therapySettingsViewModel: viewModel, chartColors: chartColorPalette, didSave: dismiss).environment(\.dismissAction, dismiss))
            }
        case .carbRatio:
            return { dismiss in
                AnyView(CarbRatioScheduleEditor(mode: mode, therapySettingsViewModel: viewModel, didSave: dismiss).environment(\.dismissAction, dismiss))
            }
        case .insulinSensitivity:
            return { dismiss in
                AnyView(InsulinSensitivityScheduleEditor(mode: mode, therapySettingsViewModel: viewModel, didSave: dismiss).environment(\.dismissAction, dismiss))
            }
        case .none:
            break
        }
        return { _ in AnyView(Text("\(setting.title)")) }
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
    
    private func card<Content>(for therapySetting: TherapySetting, @ViewBuilder content: @escaping () -> Content) -> Card where Content: View {
        Card {
            SectionWithTapToEdit(isEnabled: mode != .acceptanceFlow,
                                 title: therapySetting.title,
                                 descriptiveText: therapySetting.descriptiveText(appName: appName),
                                 destination: screen(for: therapySetting),
                                 content: content)
        }
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
                                .padding(.leading, 10)
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
                                .padding(.leading, 10)
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

struct SectionWithTapToEdit<Content, NavigationDestination>: View where Content: View, NavigationDestination: View  {
    let isEnabled: Bool
    let title: String
    let descriptiveText: String
    let destination: (_ goBack: @escaping () -> Void) -> NavigationDestination
    let content: Content

    @State var isActive: Bool = false

    init(isEnabled: Bool,
         title: String,
         descriptiveText: String,
         destination: @escaping (@escaping () -> Void) -> NavigationDestination,
         content: () -> Content)
    {
        self.isEnabled = isEnabled
        self.title = title
        self.descriptiveText = descriptiveText
        self.destination = destination
        self.content = content()
    }

    private func onFinish() {
        // Dispatching here fixes an issue on iOS 14.2 where schedule editors do not dismiss. It does not fix iOS 14.0 and 14.1
        // Added a delay, since recently a similar issue was encountered in a plugin where a delay was also needed. Still uncertain why.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isActive = false
        }
    }

    public var body: some View {
        Section {
            VStack(alignment: .leading) {
                Text(title)
                    .bold()
                Spacer()
                HStack {
                    DescriptiveText(label: descriptiveText)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    if isEnabled {
                        NavigationLink(destination: destination(onFinish), isActive: $isActive) {
                            Disclosure()
                        }
                        .frame(width: 10, alignment: .trailing)
                    }
                }
                Spacer()
            }
            content
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
    static let preview_supportedBolusVolumes = [1.0, 2.0, 3.0]
    static let preview_supportedMaximumBolusVolumes = [5.0, 10.0, 15.0]

    static func preview_viewModel() -> TherapySettingsViewModel {
        TherapySettingsViewModel(therapySettings: preview_therapySettings,
                                 pumpSupportedIncrements: {
                                    PumpSupportedIncrements(basalRates: preview_supportedBasalRates,
                                                            bolusVolumes: preview_supportedBolusVolumes,
                                                            maximumBolusVolumes: preview_supportedMaximumBolusVolumes,
                                                            maximumBasalScheduleEntryCount: 24) })
    }

    public static var previews: some View {
        Group {
            TherapySettingsView(mode: .acceptanceFlow, viewModel: preview_viewModel())
                .colorScheme(.light)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
                .previewDisplayName("SE light (onboarding)")
                .environmentObject(DisplayGlucoseUnitObservable(displayGlucoseUnit: .milligramsPerDeciliter))
            TherapySettingsView(mode: .settings, viewModel: preview_viewModel())
                .colorScheme(.light)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
                .previewDisplayName("SE light (settings)")
                .environmentObject(DisplayGlucoseUnitObservable(displayGlucoseUnit: .milligramsPerDeciliter))
            TherapySettingsView(mode: .settings, viewModel: preview_viewModel())
                .colorScheme(.dark)
                .previewDevice(PreviewDevice(rawValue: "iPhone XS Max"))
                .previewDisplayName("XS Max dark (settings)")
            TherapySettingsView(mode: .settings, viewModel: TherapySettingsViewModel(therapySettings: TherapySettings()))
                .colorScheme(.light)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
                .previewDisplayName("SE light (Empty TherapySettings)")
                .environmentObject(DisplayGlucoseUnitObservable(displayGlucoseUnit: .millimolesPerLiter))
        }
    }
}

fileprivate struct SectionDivider: View {
    var body: some View {
        Divider()
            .padding(.trailing, -16)
    }
}

fileprivate struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.trailing, -8)
    }
}

fileprivate struct Disclosure: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .imageScale(.small)
            .font(.headline)
            .foregroundColor(.secondary)
            .opacity(0.5)
    }
}
