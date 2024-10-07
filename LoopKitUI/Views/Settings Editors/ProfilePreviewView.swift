//
//  ProfilePreviewView.swift
//  LoopKitUI
//
//  Created by Jonas Björkert on 2023-05-23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import SwiftUI
import HealthKit
import LoopKit

enum ActiveAlert {
    case load
    case delete
    case error
}

struct ProfilePreviewView: View {
    @EnvironmentObject private var displayGlucosePreference: DisplayGlucosePreference
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismissAction) var dismissAction
    @Environment(\.presentationMode) var presentationMode
    var profile: Profile

    @State private var showingAlert = false
    @State private var activeAlert: ActiveAlert = .load
    @State private var errorText: String?
    @State private var newProfileName: String = ""
    @State private var isRenamingProfile = false
    @State private var shouldDismissSelf: Bool = false

    let nilDestination: (_ dismiss: @escaping () -> Void) -> AnyView = { _ in AnyView(EmptyView()) }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading) {
                    Text("Before proceeding, review the profile details below. Scroll to find options to Load, Rename, or Delete.")
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding([.leading, .trailing])
                        .fixedSize(horizontal: false, vertical: true)
                        .textCase(nil)
                    
                    profileCardStack
                    
                    Button(action: {
                        activeAlert = .load
                        showingAlert = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Load")
                                .foregroundColor(.white)
                                .padding()
                            Spacer()
                        }
                    }
                    .background(Color.blue)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    Button(action: {
                        isRenamingProfile = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Rename")
                                .foregroundColor(.white)
                                .padding()
                            Spacer()
                        }
                    }
                    .background(Color.orange)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    Button(action: {
                        activeAlert = .delete
                        showingAlert = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Delete")
                                .foregroundColor(.white)
                                .padding()
                            Spacer()
                        }
                    }
                    .background(Color.red)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                }
            }
            .navigationBarHidden(false)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(Text(profile.name))
            .alert(isPresented: $showingAlert) {
                switch activeAlert {
                case .load:
                    return Alert(
                        title: Text("Load Profile"),
                        message: Text("Do you want to load the profile \(profile.name)?"),
                        primaryButton: .default(Text("Yes"), action: {
                            let validationResult = viewModel.validateProfile(profile)
                            switch validationResult {
                            case .success:
                                viewModel.loadProfile(profile: profile) { result in
                                    switch result {
                                    case .success:
                                        dismissAction()
                                    case .failure(let error):
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            self.errorText = error.localizedDescription
                                            self.activeAlert = .error
                                            self.showingAlert = true
                                        }
                                    }
                                }
                            case .failure(let error):
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    self.errorText = error.localizedDescription
                                    self.activeAlert = .error
                                    self.showingAlert = true
                                }
                            }
                        }),
                        secondaryButton: .cancel()
                    )
                case .delete:
                    return Alert(
                        title: Text("Delete Profile"),
                        message: Text("Are you sure you want to delete the profile \(profile.name)? This action cannot be undone."),
                        primaryButton: .destructive(Text("Delete"), action: {
                            viewModel.removeProfile(profile: profile)
                            self.presentationMode.wrappedValue.dismiss()
                        }),
                        secondaryButton: .cancel()
                    )
                case .error:
                    return Alert(
                        title: Text("Error loading profile"),
                        message: Text(errorText ?? "Unknown error"),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
            if isRenamingProfile {
                // Some hacks here to mimic Alert behaviour.
                // This function should be migrateed to Alert when iOS 16 is required.
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        isRenamingProfile = false
                    }
                
                RenameProfileEditor(
                    isPresented: $isRenamingProfile,
                    currentProfileName: profile.name,
                    viewModel: viewModel,
                    shouldDismissParent: $shouldDismissSelf
                )
                .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity).animation(.default))
                .offset(y: -22)
            }
        }
        .onChange(of: shouldDismissSelf) { shouldDismiss in
            if shouldDismiss {
                self.presentationMode.wrappedValue.dismiss()
            }
        }
    }

    private var profileCardStack: CardStack {
        var cards: [Card] = []

        cards.append(correctionRangeSection)
        cards.append(carbRatioSection)
        cards.append(basalRatesSection)
        cards.append(insulinSensitivitiesSection)

        return CardStack(cards: cards)
    }

    private var correctionRangeSection: Card {
        card(for: .glucoseTargetRange) {
            if let items = profile.correctionRange.schedule(for: glucoseUnit)?.items {
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

    private var carbRatioSection: Card {
        card(for: .carbRatio) {
            SectionDivider()
            let items = profile.carbRatioSchedule.items
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

    private var basalRatesSection: Card {
        card(for: .basalRate) {
            let items = profile.basalRateSchedule.items
            if let supportedBasalRates = viewModel.pumpSupportedIncrements()?.basalRates
            {
                SectionDivider()
                let total = profile.basalRateSchedule.total()
                ForEach(items.indices, id: \.self) { index in
                    if index > 0 {
                        SettingsDivider()
                    }

                    ScheduleValueItem(time: items[index].startTime,
                                      value:  items[index].value,
                                      unit: .internationalUnitsPerHour,
                                      guardrail: .basalRate(supportedBasalRates: supportedBasalRates))
                }
                HStack {
                    Text("Total")
                        .bold()
                        .foregroundColor(.primary)
                    Spacer()
                    Text(String(format: "%.2f ",total))
                        .foregroundColor(.primary) +
                    Text("U/day")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var insulinSensitivitiesSection: Card {
        card(for: .insulinSensitivity) {
            if let items = profile.insulinSensitivitySchedule.schedule(for: glucoseUnit)?.items
            {
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
}


struct SectionWithContent<Content>: View where Content: View {
    let title: String
    let content: Content

    init(title: String,
         content: () -> Content)
    {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        Section {
            Text(title)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            content
        }
    }
}

// MARK: Utilities
extension ProfilePreviewView {

    private var glucoseUnit: HKUnit {
        displayGlucosePreference.unit
    }

    private var sensitivityUnit: HKUnit {
        glucoseUnit.unitDivided(by: .internationalUnit())
    }

    private func card<Content>(for therapySetting: TherapySetting, @ViewBuilder content: @escaping () -> Content) -> Card where Content: View {
        Card {
            SectionWithContent(title: therapySetting.title,
                               content: content)
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
