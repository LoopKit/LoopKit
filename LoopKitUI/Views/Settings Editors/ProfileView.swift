//
//  ProfileView.swift
//  LoopKitUI
//
//  Created by Jonas Björkert on 2023-04-22.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import AVFoundation
import HealthKit
import LoopKit
import SwiftUI

public struct ProfileView: View {
    @ObservedObject public var viewModel: ProfileViewModel
    @Environment(\.dismissAction) var dismissAction
    @State private var newProfileName: String = ""
    @State private var isAddingNewProfile = false
    @State private var selectedProfileIndex: Int? = nil
    @State private var refreshID = UUID()

    enum ActiveAlert: String, Identifiable {
        case update, info
        
        var id: String {
            return self.rawValue
        }
    }
    @State private var activeAlert: ActiveAlert?
    
    public init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
    }
    
    private var dismissButton: some View {
        Button(action: dismissAction) {
            Text(LocalizedString("Done", comment: "Text for dismiss button"))
                .bold()
        }
    }
    
    public var body: some View {
        ZStack {
            NavigationView {
                ConfigurationPageScrollView(
                    content: {
                        VStack(alignment: .leading) {
                            
                            if !viewModel.profiles.isEmpty {
                                List {
                                    ForEach(viewModel.profiles.indices, id: \.self) { index in
                                        if let profile = try? viewModel.getProfile(from: viewModel.profiles[index]) {
                                            NavigationLink(destination: ProfilePreviewView(viewModel: viewModel, profile: profile)) {
                                                HStack {
                                                    if viewModel.currentProfileName == viewModel.profiles[index].name {
                                                        Image(systemName: "checkmark")
                                                            .foregroundColor(Color.blue)
                                                    } else {
                                                        // Add indentation to align with the checkmark for the active profile
                                                        Image(systemName: "checkmark")
                                                            .opacity(0) // Invisible
                                                    }
                                                    
                                                    Text(viewModel.profiles[index].name)
                                                }
                                            }
                                        }
                                    }
                                    .onMove(perform: moveProfile)
                                }.id(refreshID)
                                
                            } else {
                                Text("Use ‘+’ to create a new profile capturing your glucose targets, carb ratios, basal rates, and insulin sensitivities.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding([.leading, .trailing])
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(nil)
                                    .textCase(nil)
                            }
                        }
                    },
                    actionArea: { EmptyView() } // no action area in this case
                )
                .navigationBarItems(
                    leading: HStack {
                        Button(action: { withAnimation { isAddingNewProfile = true } }) {
                            Image(systemName: "plus")
                        }
                        
                        Button(action: { activeAlert = .info }) {
                            Image(systemName: "info.circle")
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                    },
                    trailing: dismissButton
                )
                .navigationTitle(Text(LocalizedString("Profiles", comment: "Title on ProfileView")))
            }
            .navigationBarHidden(false)
            .background(Color(.systemGroupedBackground))
            .onAppear {
                if viewModel.isCurrentProfileOutOfSync() {
                    activeAlert = .update
                }
            }
            
            .alert(item: $activeAlert) { alertType in
                switch alertType {
                case .update:
                    return Alert(
                        title: Text("Profile Outdated"),
                        message: Text("The current therapy settings have changed. Do you want to update the profile named: \(viewModel.currentProfileName ?? "")?"),
                        primaryButton: .default(Text("Update")) {
                            viewModel.saveProfile(withName: viewModel.currentProfileName ?? "")
                        },
                        secondaryButton: .cancel()
                    )
                case .info:
                    return Alert(title: Text("Information"),
                                 message: Text("A checkmark next to a profile name indicates that it's the active one.\n\nUse ‘+’ to create a new profile capturing your glucose targets, carb ratios, basal rates, and insulin sensitivities.\n\nTap on any profile to review its settings in detail. In detail view, you can Load, Rename or Delete that particular profile.\n\nWant to change the order of profiles? Simply press and hold on a profile, then drag it to your desired position."),
                                 dismissButton: .default(Text("Got it!")))
                }
            }
            
            if isAddingNewProfile {
                DarkenedOverlay()
                
                NewProfileEditor(
                    isPresented: $isAddingNewProfile,
                    newProfileName: newProfileName,
                    viewModel: viewModel
                )
                .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity).animation(.default))
            }
        }
    }
    
    func moveProfile(from source: IndexSet, to destination: Int) {
        viewModel.profiles.move(fromOffsets: source, toOffset: destination)
        refreshID = UUID()
        viewModel.updateProfilesOrder()
    }
}

struct ProfileView_Previews: PreviewProvider {
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
    
    static var previews: some View {
        ProfileView(viewModel: ProfileViewModel(therapySettings: preview_therapySettings))
    }
}
