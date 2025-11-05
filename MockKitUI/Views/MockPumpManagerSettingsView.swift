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
    }
    
    @Environment(\.dismissAction) private var dismiss
    @Environment(\.guidanceColors) private var guidanceColors
    @Environment(\.insulinTintColor) private var insulinTintColor
    @ObservedObject var viewModel: MockPumpManagerSettingsViewModel
    
    @State private var showSuspendOptions = false
    @State private var presentedAlert: PresentedAlert?
    @State private var showSyncTimeOptions = false

    private var supportedInsulinTypes: [InsulinType]
    private var appName: String
    private var title: String
    
    init(pumpManager: MockPumpManager, supportedInsulinTypes: [InsulinType], appName: String) {
        viewModel = MockPumpManagerSettingsViewModel(pumpManager: pumpManager)
        title = pumpManager.localizedTitle
        self.supportedInsulinTypes = supportedInsulinTypes
        self.appName = appName
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
        suspendResumeInsulinSubSection

        replacePumpSection
        
        notificationSection
    }
    
    private var suspendResumeInsulinSubSection: some View {
        Section(header: SectionHeader(label: LocalizedString("Activity", comment: "Section header for the activity section"))) {
            Button(action: suspendResumeTapped) {
                HStack(spacing: 8) {
                    Text("").frame(maxWidth: 0)
                        .accessibilityHidden(true)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        if viewModel.suspendResumeInsulinDeliveryStatus.showPauseIcon {
                            Image(systemName: "pause.circle.fill")
                                .foregroundColor(viewModel.suspendResumeInsulinDeliveryStatus != .suspended ? nil : guidanceColors.warning)
                        }
                        
                        Text(viewModel.suspendResumeInsulinDeliveryStatus.localizedLabel)
                            .fontWeight(.semibold)
                    }
                       
                    if viewModel.transitioningSuspendResumeInsulinDelivery {
                        ProgressView()
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
                .actionSheet(isPresented: $showSuspendOptions) {
                   suspendOptionsActionSheet
                }
            }
            .disabled(viewModel.transitioningSuspendResumeInsulinDelivery)
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
    
    private var replacePumpSection: some View {
        Section {
            NavigationLink(destination: DemoPlaceHolderView(appName: appName)) {
                Text("Replace Pump")
                    .foregroundColor(guidanceColors.critical)
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
        }
    }
}

struct MockPumpManagerSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        MockPumpManagerSettingsView(pumpManager: MockPumpManager(), supportedInsulinTypes: [], appName: "Loop")
    }
}
