//
//  MockCGMManagerSettingsView.swift
//  MockKitUI
//
//  Created by Nathaniel Hamming on 2023-05-18.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI
import MockKit

struct MockCGMManagerSettingsView: View {
    fileprivate enum PresentedAlert {
        case resumeInsulinDeliveryError(Error)
        case suspendInsulinDeliveryError(Error)
    }
    
    @Environment(\.dismissAction) private var dismiss
    @Environment(\.guidanceColors) private var guidanceColors
    @Environment(\.glucoseTintColor) private var glucoseTintColor
    @ObservedObject var viewModel: MockCGMManagerSettingsViewModel
    
    @State private var showSuspendOptions = false
    @State private var presentedAlert: PresentedAlert?
    private var displayGlucosePreference: DisplayGlucosePreference
    private let appName: String
    private let allowDebugFeatures : Bool
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init(cgmManager: MockCGMManager, displayGlucosePreference: DisplayGlucosePreference, appName: String, allowDebugFeatures: Bool) {
        viewModel = MockCGMManagerSettingsViewModel(cgmManager: cgmManager, displayGlucosePreference: displayGlucosePreference)
        self.displayGlucosePreference = displayGlucosePreference
        self.appName = appName
        self.allowDebugFeatures = allowDebugFeatures
    }
    
    var body: some View {
        List {
            statusSection
            
            sensorSection
            
            lastReadingSection
            
            supportSection
        }
        .insetGroupedListStyle()
        .navigationBarItems(trailing: doneButton)
        .navigationBarTitle(Text("CGM Simulator"), displayMode: .large)
        .alert(item: $presentedAlert, content: alert(for:))
    }
    
    @ViewBuilder
    private var statusSection: some View {
        statusCardSubSection
        
        notificationSubSection
        
        if (allowDebugFeatures) {
            settingsSubSection
        }
    }
    
    private var statusCardSubSection: some View {
        Section {
            VStack(spacing: 8) {
                sensorProgressView
                    .openMockCGMSettingsOnLongPress(enabled: true, cgmManager: viewModel.cgmManager, displayGlucosePreference: displayGlucosePreference)
                Divider()
                lastReadingInfo
            }
        }
    }
        
    private var sensorProgressView: some View {
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
            Image(frameworkImage: "CGM Simulator")
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
        Text("Sensor expires in ")
            .font(.subheadline)
            .foregroundColor(.secondary)
    }
    
    private var expirationTime: some View {
        HStack(alignment: .lastTextBaseline) {
            Text("5")
                .font(.system(size: 24, weight: .heavy, design: .default))
            Text("days")
                .font(.system(size: 15, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .offset(x: -3)
        }
    }
    
    private var progressBar: some View {
        ProgressView(progress: viewModel.sensorExpirationPercentComplete)
            .accentColor(glucoseTintColor)
    }
    
    var lastReadingInfo: some View {
        HStack(alignment: .lastTextBaseline) {
            lastGlucoseReading
                .frame(idealWidth: 100)
            Spacer()
            lastReadingTime
                .onReceive(timer) { _ in
                    // Update every second
                    viewModel.updateLastReadingTime()
                }
        }
    }
    
    @ViewBuilder
    private var lastGlucoseReading: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Last Reading")
                .foregroundColor(.secondary)
            
            HStack(alignment: .center, spacing: 16) {
                viewModel.lastGlucoseTrend?.filledImage
                    .scaleEffect(1.7, anchor: .leading)
                    .foregroundColor(glucoseTintColor)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(viewModel.lastGlucoseValueFormatted)
                        .font(.title)
                        .fontWeight(.heavy)
                    Text(viewModel.glucoseUnitString)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private var lastReadingTime: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .scaleEffect(1.7, anchor: .leading)
                .foregroundColor(glucoseTintColor)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(viewModel.lastReadingMinutesFromNow)")
                    .font(.title)
                    .fontWeight(.heavy)
                Text("min")
                    .foregroundColor(.secondary)
            }
        }
        .frame(height: 40.0)
    }
    
    private var notificationSubSection: some View {
        Section {
            NavigationLink(destination: DemoPlaceHolderView(appName: appName)) {
                Text("Notification Settings")
            }
        }
    }
    
    private var settingsSubSection: some View {
        Section {
            NavigationLink(destination: MockCGMManagerControlsView(cgmManager: viewModel.cgmManager, displayGlucosePreference: displayGlucosePreference)) {
                Text("Simulator Settings")
            }
        }
    }
    
    @ViewBuilder
    private var sensorSection: some View {
        deviceDetailsSubSection

        stopSensorSubSection
    }
    
    private var deviceDetailsSubSection: some View {
        Section(header: SectionHeader(label: "Sensor")) {
            LabeledValueView(label: "Insertion Time", value: viewModel.sensorInsertionDateTimeString)
            
            LabeledValueView(label: "Sensor Expires", value: viewModel.sensorExpirationDateTimeString)
        }
    }
    
    private var stopSensorSubSection: some View {
        Section {
            NavigationLink(destination: DemoPlaceHolderView(appName: appName)) {
                Text("Stop Sensor")
                    .foregroundColor(guidanceColors.critical)
            }
        }
    }

    private var lastReadingSection: some View {
        Section(header: SectionHeader(label: "Last Reading")) {
            LabeledValueView(label: "Glucose", value: viewModel.lastGlucoseValueWithUnitFormatted)
            LabeledValueView(label: "Time", value: viewModel.lastGlucoseDateFormatted)
            LabeledValueView(label: "Trend", value: viewModel.lastGlucoseTrendFormatted)
        }
    }
    
    private var supportSection: some View {
        Section(header: SectionHeader(label: "Support")) {
            NavigationLink(destination: DemoPlaceHolderView(appName: appName)) {
                Text("Get help with your CGM")
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

extension MockCGMManagerSettingsView.PresentedAlert: Identifiable {
    var id: Int {
        switch self {
        case .resumeInsulinDeliveryError:
            return 0
        case .suspendInsulinDeliveryError:
            return 1
        }
    }
}

struct MockCGMManagerSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        MockCGMManagerSettingsView(cgmManager: MockCGMManager(), displayGlucosePreference: DisplayGlucosePreference(displayGlucoseUnit: .milligramsPerDeciliter), appName: "Loop", allowDebugFeatures: false)
    }
}

