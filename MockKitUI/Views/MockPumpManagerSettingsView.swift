//
//  MockPumpManagerSettingsView.swift
//  MockKitUI
//
//  Created by Nathaniel Hamming on 2023-05-18.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI
import MockKit
import LoopAlgorithm

struct MockPumpManagerSettingsView: View {
    fileprivate enum PresentedAlert {
        case resumeInsulinDeliveryError(Error)
        case suspendInsulinDeliveryError(Error)
        case syncTimeError(Error)
        case cancelManualTempBasalError(Error)
    }

    @Environment(\.dismissAction) private var dismiss
    @Environment(\.guidanceColors) private var guidanceColors
    @Environment(\.insulinTintColor) private var insulinTintColor
    @ObservedObject var viewModel: MockPumpManagerSettingsViewModel

    @State private var showSuspendOptions = false
    @State private var presentedAlert: PresentedAlert?
    @State private var showSyncTimeOptions = false
    @State private var showManualTempBasalOptions = false
    @State private var cancelingTempBasal = false

    private var supportedInsulinTypes: [InsulinType]
    private var appName: String
    private let allowDebugFeatures : Bool
    private var title: String
    
    init(pumpManager: MockPumpManager, supportedInsulinTypes: [InsulinType], appName: String, allowDebugFeatures: Bool) {
        viewModel = MockPumpManagerSettingsViewModel(pumpManager: pumpManager)
        title = pumpManager.localizedTitle
        self.supportedInsulinTypes = supportedInsulinTypes
        self.appName = appName
        self.allowDebugFeatures = allowDebugFeatures
    }
    
    var body: some View {
        List {
            statusSection
            
            activitySection
            
            configurationSection
            
            supportSection
        }
        .insetGroupedListStyle()
        .navigationBarItems(trailing: doneButton)
        .navigationBarTitle(Text(title), displayMode: .large)
        .alert(item: $presentedAlert, content: alert(for:))
    }
    
    @ViewBuilder
    private var statusSection: some View {
        Section {
            VStack(spacing: 8) {
                pumpProgressView
                    .accessibilityIdentifier("mockPumpManagerProgressView")
                    .openMockPumpSettingsOnLongPress(enabled: true, pumpManager: viewModel.pumpManager, supportedInsulinTypes: supportedInsulinTypes)
                Divider()
                insulinInfo
            }
        }
    }
    
    private var pumpProgressView: some View {
        HStack(alignment: .center, spacing: 16) {
            pumpImage
            expirationArea
                .offset(y: -3)
        }
    }
    
    private var pumpImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(frameworkColor: "LightGrey")!)
                .frame(width: 77, height: 76)
            Image(frameworkImage: "Pump Simulator")
                .resizable()
                .aspectRatio(contentMode: ContentMode.fit)
                .frame(maxHeight: 70)
                .frame(width: 70)
        }
    }
    
    private var expirationArea: some View {
        VStack(alignment: .leading) {
            expirationText
                .offset(y: 4)
            expirationTime
                .offset(y: 10)
            progressBar
        }
    }
    
    private var expirationText: some View {
        Text("Pump expires in ")
            .font(.subheadline)
            .foregroundColor(.secondary)
    }
    
    private var expirationTime: some View {
        HStack(alignment: .lastTextBaseline) {
            Text("2")
                .font(.system(size: 24, weight: .heavy, design: .default))
            Text("days")
                .font(.system(size: 15, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .offset(x: -3)
        }
    }
    
    private var progressBar: some View {
        ProgressView(progress: viewModel.pumpExpirationPercentComplete)
            .accentColor(insulinTintColor)
    }
    
    var insulinInfo: some View {
        InsulinStatusView(viewModel: viewModel)
            .environment(\.guidanceColors, guidanceColors)
            .environment(\.insulinTintColor, insulinTintColor)
    }
    
    @ViewBuilder
    private var activitySection: some View {

        if (allowDebugFeatures) {
            settingsSubSection
        }

        suspendResumeInsulinSubSection

        manualTempBasalSubSection

        notificationSection
    }

    private var manualTempBasalSubSection: some View {
        Section {
            if let manualTempRemaining = viewModel.manualBasalTimeRemaining,
               let remainingText = viewModel.timeRemainingFormatter.string(from: manualTempRemaining) {
                HStack {
                    if cancelingTempBasal {
                        ProgressView()
                            .padding(.trailing)
                    } else {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(guidanceColors.warning)
                    }
                    Button(action: cancelManualTempBasal) {
                        Text(LocalizedString("Cancel Manual Basal", comment: "Button title to cancel manual basal"))
                    }
                }
                HStack {
                    Text(LocalizedString("Remaining", comment: "Label for remaining time of manual basal"))
                    Spacer()
                    Text(remainingText)
                        .foregroundColor(.secondary)
                }
            } else {
                Button(action: { showManualTempBasalOptions = true }) {
                    Text(LocalizedString("Set Temporary Basal Rate", comment: "Button title to set temporary basal rate"))
                }
                .sheet(isPresented: $showManualTempBasalOptions) {
                    ManualTempBasalEntryView(
                        enactBasal: { rate, duration, completion in
                            viewModel.runTemporaryBasalProgram(decisionId: nil, unitsPerHour: rate, for: duration) { error in
                                completion(error)
                                if error == nil {
                                    showManualTempBasalOptions = false
                                }
                            }
                        },
                        didCancel: { showManualTempBasalOptions = false },
                        allowedRates: viewModel.allowedTempBasalRates,
                        supportedDurations: viewModel.supportedTempBasalDurations
                    )
                }
            }
        }
        .disabled(cancelingTempBasal || viewModel.insulinDeliveryDisabled || viewModel.isDeliverySuspended)
    }

    private func cancelManualTempBasal() {
        cancelingTempBasal = true
        viewModel.cancelManualTempBasal { error in
            cancelingTempBasal = false
            if let error = error {
                presentedAlert = .cancelManualTempBasalError(error)
            }
        }
    }
    
    private var suspendResumeInsulinSubSection: some View {
        Section(header: SectionHeader(label: LocalizedString("Activity", comment: "Section header for the activity section"))) {
            Button(action: suspendResumeTapped) {
                HStack {
                    if viewModel.suspendResumeInsulinDeliveryStatus.showPauseIcon {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(viewModel.suspendResumeInsulinDeliveryStatus != .suspended ? nil : guidanceColors.warning)
                    }
                    Text(viewModel.suspendResumeInsulinDeliveryStatus.localizedLabel)
                    Spacer()
                    if viewModel.transitioningSuspendResumeInsulinDelivery {
                        ProgressView()
                    }
                }
                .actionSheet(isPresented: $showSuspendOptions) {
                   suspendOptionsActionSheet
                }
            }
            .disabled(viewModel.transitioningSuspendResumeInsulinDelivery || viewModel.insulinDeliveryDisabled)
            if viewModel.isDeliverySuspended {
                LabeledValueView(label: LocalizedString("Suspended At", comment: "Label for suspended at field"),
                                 value: viewModel.suspendedAtString)
            }
        }
    }
    
    private var suspendOptionsActionSheet: ActionSheet {
        let completion: (Error?) -> Void = { (error) in
            if let error = error {
                self.presentedAlert = .suspendInsulinDeliveryError(error)
            }
        }

        var suspendReminderDelayOptions: [SwiftUI.Alert.Button] = viewModel.suspendReminderDelayOptions.map { suspendReminderDelay in
            .default(Text(viewModel.suspendReminderTimeFormatter.string(from: suspendReminderDelay)!),
                     action: { viewModel.suspendInsulinDelivery(reminderDelay: suspendReminderDelay, completion: completion) })
        }
        suspendReminderDelayOptions.append(.cancel())

        return ActionSheet(
            title: FrameworkLocalizedText("Delivery Suspension Reminder", comment: "Title for suspend duration selection action sheet"),
            message: FrameworkLocalizedText("How long would you like to suspend insulin delivery for?", comment: "Message for suspend duration selection action sheet"),
            buttons: suspendReminderDelayOptions)
    }
    
    private func suspendResumeTapped() {
        if viewModel.isDeliverySuspended {
            viewModel.resumeInsulinDelivery { error in
                if let error = error {
                    self.presentedAlert = .resumeInsulinDeliveryError(error)
                }
            }
        } else {
            showSuspendOptions = true
        }
    }
    
    private var deviceDetailsSubSection: some View {
        Section {
            LabeledValueView(label: "Pump Paired", value: viewModel.lastPumpPairedDateTimeString)
            
            LabeledValueView(label: "Pump Expires", value: viewModel.pumpExpirationDateTimeString)

            LabeledValueView(label: "Current Basal Rate", value: viewModel.currentBasalRate)


            NavigationLink(destination: DemoPlaceHolderView(appName: appName)) {
                Text("Device Details")
            }
        }
    }
    
    private var settingsSubSection: some View {
        Section {
            NavigationLink(destination: MockPumpManagerControlsView(pumpManager: viewModel.pumpManager, supportedInsulinTypes: supportedInsulinTypes)) {
                Text("Simulator Settings")
            }
        }
    }

    @ViewBuilder
    private var configurationSection: some View {
        Section(header: SectionHeader(label: "Configuration")) {
            deviceDetailsSubSection
        }
        
        pumpTimeSubSection
    }
    
    private var notificationSection: some View {
        NavigationLink(destination: DemoPlaceHolderView(appName: appName)) {
            Text("Notification Settings")
        }
    }
    
    private var pumpTimeSubSection: some View {
        Section(footer: pumpTimeSubSectionFooter) {
            HStack {
                FrameworkLocalizedText("Pump Time", comment: "The title of the command to change pump time zone")
                    .foregroundColor(viewModel.canSynchronizePumpTime ? .primary : guidanceColors.critical)
                Spacer()
                if viewModel.isClockOffset {
                    Image(systemName: "clock.fill")
                        .foregroundColor(guidanceColors.warning)
                }
                TimeView(timeOffset: viewModel.detectedSystemTimeOffset, timeZone: viewModel.timeZone)
                    .foregroundColor(viewModel.isClockOffset ? guidanceColors.warning : nil)
            }
            if viewModel.synchronizingTime {
                HStack {
                    FrameworkLocalizedText("Adjusting Pump Time...", comment: "Text indicating ongoing pump time synchronization")
                        .foregroundColor(.secondary)
                    Spacer()
                    ActivityIndicator(isAnimating: .constant(true), style: .medium)
                }
            } else if self.viewModel.timeZone != TimeZone.currentFixed,
                      viewModel.canSynchronizePumpTime
            {
                Button(action: {
                    showSyncTimeOptions = true
                }) {
                    FrameworkLocalizedText("Sync to Current Time", comment: "The title of the command to change pump time zone")
                }
                .actionSheet(isPresented: $showSyncTimeOptions) {
                    syncPumpTimeActionSheet
                }
            }
        }
    }
    
    var syncPumpTimeActionSheet: ActionSheet {
       ActionSheet(title: FrameworkLocalizedText("Time Change Detected", comment: "Title for pump sync time action sheet."), message: FrameworkLocalizedText("The time on your pump is different from the current time. Do you want to update the time on your pump to the current time?", comment: "Message for pump sync time action sheet"), buttons: [
          .default(FrameworkLocalizedText("Yes, Sync to Current Time", comment: "Button text to confirm pump time sync")) {
              self.viewModel.changeTimeZoneTapped() { error in
                  if let error = error {
                      self.presentedAlert = .syncTimeError(error)
                  }
              }
          },
          .cancel(FrameworkLocalizedText("No, Keep Pump As Is", comment: "Button text to cancel pump time sync"))
       ])
    }
        
    @ViewBuilder
    private var pumpTimeSubSectionFooter: some View {
        if !viewModel.canSynchronizePumpTime {
            FrameworkLocalizedText("When the device time is manually set, Tidepool Loop will not synchronize the pump time to the device time.", comment: "Description for why the pump time is not synchronized")
        }
    }
    
    private var supportSection: some View {
        Section(header: SectionHeader(label: "Support")) {
            NavigationLink(destination: DemoPlaceHolderView(appName: appName)) {
                Text("Get help with your pump")
            }
        }
    }
    
    private var doneButton: some View {
        Button(LocalizedString("Done", comment: "Settings done button label"), action: dismiss)
    }
    
    private func alert(for presentedAlert: PresentedAlert) -> SwiftUI.Alert {
        switch presentedAlert {
        case .suspendInsulinDeliveryError(let error):
            return Alert(
                title: Text("Failed to Suspend Insulin Delivery"),
                message: Text(error.localizedDescription)
            )
        case .resumeInsulinDeliveryError(let error):
            return Alert(
                title: Text("Failed to Resume Insulin Delivery"),
                message: Text(error.localizedDescription)
            )
        case .syncTimeError(let error):
            return SwiftUI.Alert(
               title: FrameworkLocalizedText("Failed to Set Pump Time", comment: "Alert title for time sync error"),
               message: Text(error.localizedDescription)
            )
        case .cancelManualTempBasalError(let error):
            return Alert(
                title: Text(LocalizedString("Failed to Cancel Manual Basal", comment: "Alert title for failure to cancel manual basal")),
                message: Text(error.localizedDescription)
            )
        }
    }
}

extension MockPumpManagerSettingsView.PresentedAlert: Identifiable {
    var id: Int {
        switch self {
        case .resumeInsulinDeliveryError:
            return 0
        case .suspendInsulinDeliveryError:
            return 1
        case .syncTimeError:
            return 2
        case .cancelManualTempBasalError:
            return 3
        }
    }
}

private struct ManualTempBasalEntryView: View {
    @Environment(\.guidanceColors) private var guidanceColors

    let enactBasal: (Double, TimeInterval, @escaping (PumpManagerError?) -> Void) -> Void
    let didCancel: () -> Void
    let allowedRates: [Double]
    let supportedDurations: [TimeInterval]

    @State private var rateEntered: Double = 0.0
    @State private var durationEntered: TimeInterval = .hours(0.5)
    @State private var enacting = false
    @State private var error: PumpManagerError?
    @State private var showingErrorAlert = false

    private static let rateFormatter: QuantityFormatter = {
        let f = QuantityFormatter(for: .internationalUnitsPerHour)
        f.numberFormatter.minimumFractionDigits = 2
        return f
    }()

    private static let durationFormatter: QuantityFormatter = {
        let f = QuantityFormatter(for: .hour)
        f.numberFormatter.minimumFractionDigits = 1
        f.numberFormatter.maximumFractionDigits = 1
        f.unitStyle = .long
        return f
    }()

    private func formatRate(_ rate: Double) -> String {
        Self.rateFormatter.string(from: LoopQuantity(unit: .internationalUnitsPerHour, doubleValue: rate)) ?? ""
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        Self.durationFormatter.string(from: LoopQuantity(unit: .hour, doubleValue: duration.hours)) ?? ""
    }

    var body: some View {
        NavigationView {
            VStack {
                List {
                    HStack {
                        Text(LocalizedString("Rate", comment: "Label text for basal rate summary"))
                        Spacer()
                        Text(String(format: LocalizedString("%1$@ for %2$@", comment: "Summary string for temporary basal rate configuration page"), formatRate(rateEntered), formatDuration(durationEntered)))
                    }
                    HStack {
                        Picker(selection: $rateEntered) {
                            ForEach(allowedRates, id: \.self) { value in
                                Text(formatRate(value))
                            }
                        } label: { EmptyView() }
                            .pickerStyle(.wheel)

                        Picker(selection: $durationEntered) {
                            ForEach(supportedDurations, id: \.self) { value in
                                Text(formatDuration(value))
                            }
                        } label: { EmptyView() }
                            .pickerStyle(.wheel)
                    }
                    .frame(maxHeight: 162.0)

                    Section {
                        Text(LocalizedString("Your insulin delivery will not be automatically adjusted until the temporary basal rate finishes or is canceled.", comment: "Description text on manual temp basal action sheet"))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Button(action: {
                    enacting = true
                    enactBasal(rateEntered, durationEntered) { error in
                        if let error = error {
                            self.error = error
                            showingErrorAlert = true
                        }
                        enacting = false
                    }
                }) {
                    HStack {
                        if enacting {
                            ProgressView()
                        } else {
                            Text(LocalizedString("Set Temporary Basal", comment: "Button text for setting manual temporary basal rate"))
                        }
                    }
                }
                .buttonStyle(ActionButtonStyle(.primary))
                .padding()
            }
            .navigationTitle(LocalizedString("Temporary Basal", comment: "Navigation Title for ManualTempBasalEntryView"))
            .navigationBarItems(trailing: Button(LocalizedString("Cancel", comment: "Cancel button text"), action: didCancel))
            .alert(isPresented: $showingErrorAlert) {
                let recovery = error?.recoverySuggestion
                let message: Text
                if let recovery = recovery, let error = error {
                    message = Text(String(format: LocalizedString("Unable to set a temporary basal rate: %1$@\n\n%2$@", comment: "Alert format string for a failure to set temporary basal with recovery suggestion. (1: error description) (2: recovery text)"), error.localizedDescription, recovery))
                } else if let error = error {
                    message = Text(String(format: LocalizedString("Unable to set a temporary basal rate: %1$@", comment: "Alert format string for a failure to set temporary basal. (1: error description)"), error.localizedDescription))
                } else {
                    message = Text("")
                }
                return Alert(
                    title: Text(LocalizedString("Temporary Basal Failed", comment: "Alert title for a failure to set temporary basal")),
                    message: message
                )
            }
            .disabled(enacting)
        }
    }
}

struct MockPumpManagerSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        MockPumpManagerSettingsView(pumpManager: MockPumpManager(), supportedInsulinTypes: [], appName: "Loop", allowDebugFeatures: false)
    }
}
