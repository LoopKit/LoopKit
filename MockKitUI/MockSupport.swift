//
//  MockSupport.swift
//  MockKitUI
//
//  Created by Rick Pasetto on 10/13/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import LoopKitUI
import MockKit
import SwiftUI

public class MockSupport: SupportUI {
    public static let supportIdentifier = "MockSupport"
    
    public var pluginIdentifier: String { Self.supportIdentifier }
    
    var versionUpdate: VersionUpdate?
    var alertIssuer: AlertIssuer? {
        return self.delegate
    }
    var lastVersionCheckAlertDate: Date?

    public init() { }

    public required init?(rawState: RawStateValue) {
        lastVersionCheckAlertDate = rawState["lastVersionCheckAlertDate"] as? Date
    }
    
    public var rawState: RawStateValue {
        var rawValue: RawStateValue = [:]
        rawValue["lastVersionCheckAlertDate"] = lastVersionCheckAlertDate
        return rawValue
    }
   
    public func checkVersion(bundleIdentifier: String, currentVersion: String) async -> VersionUpdate? {
        let update = versionUpdate ?? .noUpdateNeeded
        if update != .required {
            maybeIssueAlert(update)
        }
        return versionUpdate
    }
    
    public weak var delegate: SupportUIDelegate?

    public func configurationMenuItems() -> [LoopKitUI.CustomMenuItem] {
        return [
            CustomMenuItem(section: .support, view: AnyView(SupportMenuItem(mockSupport: self)))
        ]
    }
    
    public func softwareUpdateView(bundleIdentifier: String, currentVersion: String, guidanceColors: GuidanceColors, openAppStore: (() -> Void)?) -> AnyView? {
        guard let versionUpdate, versionUpdate.softwareUpdateAvailable else {
            return nil
        }
        return AnyView(
            MockSoftwareUpdateView(
                versionUpdate: versionUpdate,
                currentVersion: currentVersion,
                guidanceColors: guidanceColors,
                openAppStore: openAppStore
            )
        )
    }
    
    public func getScenarios(from scenarioURLs: [URL]) -> [LoopScenario] {
        scenarioURLs.map { LoopScenario(name: $0.lastPathComponent, url: $0) }
    }
    
    public func loopWillReset() {}
    
    public func loopDidReset() {}
    
    public func trainingMedia(for domain: TrainingMediaDomain) -> [MediaContent] { [] }
}

extension MockSupport {
    
    var alertCadence: TimeInterval {
        return TimeInterval.minutes(1)
    }
    
    private var appName: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as! String
    }

    static func updateDescription(for versionUpdate: VersionUpdate) -> String {
        switch versionUpdate {
        case .required:
            return LocalizedString("A critical update is available. Your app may not function correctly until you update to the latest version.", comment: "Software update description for required update")
        case .recommended:
            return LocalizedString("Your app is out of date. It will continue to work, but we recommend updating to the latest version.", comment: "Software update description for recommended update")
        case .available:
            return LocalizedString("A new version is ready for you. Please update through the App Store.", comment: "Software update description for available update")
        case .noUpdateNeeded:
            return ""
        }
    }

    private func maybeIssueAlert(_ versionUpdate: VersionUpdate) {
        guard versionUpdate >= .recommended else {
            noAlertNecessary()
            return
        }
        
        let alertIdentifier = Alert.Identifier(managerIdentifier: MockSupport.supportIdentifier, alertIdentifier: versionUpdate.rawValue)
        let description = Self.updateDescription(for: versionUpdate)
        let navigationGuidance = String(format: LocalizedString("\n\nGo to %1$@ Settings > Software Update to complete.", comment: "Navigation guidance appended to software update alerts (1: app name)"), appName)
        let alertContent: LoopKit.Alert.Content
        if firstAlert {
            alertContent = Alert.Content(title: versionUpdate.localizedDescription,
                                         body: description + navigationGuidance,
                                         acknowledgeActionButtonLabel: LocalizedString("OK", comment: "Default acknowledgement"))
        } else if let lastVersionCheckAlertDate = lastVersionCheckAlertDate,
                  abs(lastVersionCheckAlertDate.timeIntervalSinceNow) > alertCadence {
            alertContent = Alert.Content(title: LocalizedString("Update Reminder", comment: "Recurring software update alert title"),
                                         body: description + navigationGuidance,
                                         acknowledgeActionButtonLabel: LocalizedString("OK", comment: "Default acknowledgement"))
        } else {
            return
        }
        let interruptionLevel: LoopKit.Alert.InterruptionLevel = versionUpdate == .required ? .critical : .active
        Task {
            await alertIssuer?.issueAlert(Alert(identifier: alertIdentifier, foregroundContent: alertContent, backgroundContent: alertContent, trigger: .immediate, interruptionLevel: interruptionLevel))
            recordLastAlertDate()
        }
    }
    
    private func noAlertNecessary() {
        lastVersionCheckAlertDate = nil
    }
    
    private var firstAlert: Bool {
        return lastVersionCheckAlertDate == nil
    }
    
    private func recordLastAlertDate() {
        lastVersionCheckAlertDate = Date()
    }
    
}

struct SupportMenuItem : View {
    
    let mockSupport: MockSupport
    
    @State var showActionSheet: Bool = false
    
    private var buttons: [ActionSheet.Button] {
        VersionUpdate.allCases.map { versionUpdate in
            let setter = { mockSupport.versionUpdate = versionUpdate }
            switch versionUpdate {
            case .required:
                return ActionSheet.Button.destructive(Text(versionUpdate.localizedDescription), action: setter)
            default:
                return ActionSheet.Button.default(Text(versionUpdate.localizedDescription), action: setter)
            }
        } +
        [.cancel(Text("Cancel"))]
    }

    private var actionSheet: ActionSheet {
        ActionSheet(title: Text("Version Check Response"), message: Text("How should the simulator respond to a version check?"), buttons: buttons)
    }

    var body: some View {
        Button(action: {
            self.showActionSheet.toggle()
        }) {
            Text("Mock Version Check \(currentVersionUpdate)")
        }
        .actionSheet(isPresented: $showActionSheet, content: {
            self.actionSheet
        })
        
        Button(action: { mockSupport.lastVersionCheckAlertDate = nil } ) {
            Text("Clear Last Version Check Alert Date")
        }
    }
    
    var currentVersionUpdate: String {
        return mockSupport.versionUpdate.map { "(\($0.rawValue))" } ?? ""
    }
}

struct MockSoftwareUpdateView: View {

    let versionUpdate: VersionUpdate
    let currentVersion: String
    let guidanceColors: GuidanceColors
    let openAppStore: (() -> Void)?

    private var iconColor: Color {
        switch versionUpdate {
        case .required: return guidanceColors.critical
        case .recommended: return guidanceColors.warning
        default: return .primary
        }
    }

    private var bodyText: String {
        MockSupport.updateDescription(for: versionUpdate)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if versionUpdate >= .recommended {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(iconColor)
                        }
                        Text(versionUpdate.localizedDescription)
                            .bold()
                    }
                    .padding(.vertical, 5)

                    Text(bodyText)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 5)

                    Divider()

                    Button(action: { openAppStore?() }) {
                        HStack {
                            Text("App Store to Download and Install")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .font(.footnote)
                        }
                    }
                    .accentColor(.primary)
                    .padding(.vertical, 5)
                }
            }

            Section {
                HStack {
                    Text("Current Version")
                    Spacer()
                    Text(currentVersion)
                        .foregroundColor(.secondary)
                }
            }
        }
        .insetGroupedListStyle()
        .navigationBarTitle(Text("Software Update"))
    }
}

extension MockService: @retroactive SupportProviding {
    public func createSupport() -> SupportUI {
        return MockSupport()
    }
}
