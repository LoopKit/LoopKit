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

struct MockPumpManagerSettingsView: View {
    fileprivate enum PresentedAlert {
        case resumeInsulinDeliveryError(Error)
        case suspendInsulinDeliveryError(Error)
    }
    
    @Environment(\.dismissAction) private var dismiss
    @Environment(\.guidanceColors) private var guidanceColors
    @Environment(\.insulinTintColor) private var insulinTintColor
    @ObservedObject var viewModel: MockPumpManagerSettingsViewModel
    
    @State private var showSuspendOptions = false
    @State private var presentedAlert: PresentedAlert?

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

        deviceDetailsSubSection

        replaceSystemComponentsSubSection
    }
    
    private var suspendResumeInsulinSubSection: some View {
        Section(header: SectionHeader(label: LocalizedString("Activity", comment: "Section header for the activity section"))) {
            Button(action: suspendResumeTapped) {
                HStack {
                    Image(systemName: "pause.circle.fill")
                        .foregroundColor(viewModel.isDeliverySuspended ? guidanceColors.warning : .accentColor)
                    Text(viewModel.suspendResumeInsulinDeliveryLabel)
                    Spacer()
                    if viewModel.transitioningSuspendResumeInsulinDelivery {
                        ActivityIndicator(isAnimating: .constant(true), style: .medium)
                    }
                }
            }
            .disabled(viewModel.transitioningSuspendResumeInsulinDelivery)
            if viewModel.isDeliverySuspended {
                LabeledValueView(label: LocalizedString("Suspended At", comment: "Label for suspended at field"),
                                 value: viewModel.suspendedAtString)
            }
        }
    }
    
    private func suspendResumeTapped() {
        if viewModel.isDeliverySuspended {
            viewModel.resumeDelivery() { error in
                if let error = error {
                    self.presentedAlert = .resumeInsulinDeliveryError(error)
                }
            }
        } else {
            viewModel.suspendDelivery() { error in
                if let error = error {
                    self.presentedAlert = .suspendInsulinDeliveryError(error)
                }
            }
        }
    }
    
    private var deviceDetailsSubSection: some View {
        Section {
            LabeledValueView(label: "Pump Paired", value: viewModel.lastPumpPairedDateTimeString)
            
            LabeledValueView(label: "Pump Expires", value: viewModel.pumpExpirationDateTimeString)
            
            NavigationLink(destination: DemoPlaceHolderView(appName: appName)) {
                Text("Device Details")
            }
        }
    }
    
    private var replaceSystemComponentsSubSection: some View {
        Section {
            NavigationLink(destination: DemoPlaceHolderView(appName: appName)) {
                Text("Replace Pump")
                    .foregroundColor(.accentColor)
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
        notificationSubSection
        
        pumpTimeSubSection
    }
    
    private var notificationSubSection: some View {
        Section(header: SectionHeader(label: "Configuration")) {
            NavigationLink(destination: DemoPlaceHolderView(appName: appName)) {
                Text("Notification Settings")
            }
        }
    }
    
    private var pumpTimeSubSection: some View {
        Section {
            TimeView(label: "Pump Time")
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
        }
    }
}

struct MockPumpManagerSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        MockPumpManagerSettingsView(pumpManager: MockPumpManager(), supportedInsulinTypes: [], appName: "Loop", allowDebugFeatures: false)
    }
}
