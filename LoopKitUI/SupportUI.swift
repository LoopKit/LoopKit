//
//  SupportUI.swift
//  LoopKitUI
//
//  Created by Darin Krauss on 12/10/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit

public protocol SupportInfoProvider {
    var pumpStatus: PumpManagerStatus? { get }
    var cgmStatus: CGMManagerStatus? { get }
    var localizedAppNameAndVersion: String { get }
    func generateIssueReport(completion: @escaping (String) -> Void)
}

public struct LoopScenario: Hashable {
    public let name: String
    public let url: URL
    
    public init(name: String, url: URL) {
        self.name = name
        self.url = url
    }
}

public enum SettingsMenuSection: Equatable {
    case configuration
    case support
    case custom(localizedTitle: String)

    public var customLocalizedTitle: String? {
        switch self {
        case .custom(let title):
            return title
        default:
            return nil
        }
    }
}

public struct CustomMenuItem {
    public let section: SettingsMenuSection
    public let view: AnyView

    public init(section: SettingsMenuSection, view: AnyView) {
        self.section = section
        self.view = view
    }
}

public protocol SupportUIDelegate: AlertIssuer, SupportInfoProvider  {
    func openURL(url: URL)
}

public struct DeviceWhitelist: Hashable {
    public let cgmDevices: [String]
    public let pumpDevices: [String]
    
    public init(cgmDevices: [String] = [], pumpDevices: [String] = []) {
        self.cgmDevices = cgmDevices
        self.pumpDevices = pumpDevices
    }
}

public protocol SupportUI: Pluggable {

    typealias RawStateValue = [String: Any]

    /// Provides configuration menu items.
    ///
    /// - Returns: An array of views that will be added to the configuration section of settings.
    func configurationMenuItems() -> [CustomMenuItem]

    ///
    /// Check whether the given app version for the given `bundleIdentifier` needs an update.  Services should return their last result, if known.
    ///  If version cannot be checked or checking version fails, nil should be returned.
    ///
    /// - Parameters:
    ///    - bundleIdentifier: The host app's `bundleIdentifier` (a.k.a. `CFBundleIdentifier`) string.
    ///    - currentVersion: The host app's current version (i.e. `CFBundleVersion`).
    /// - returns: A VersionUpdate object describing the update status
    func checkVersion(bundleIdentifier: String, currentVersion: String) async -> VersionUpdate?

    /// Provides screen for software update UI.
    ///
    /// - Parameters:
    ///    - bundleIdentifier: The host app's bundle identifier (e.g. `Bundle.main.bundleIdentifier`).
    ///    - currentVersion: The host app's current version (i.e. `CFBundleVersion`).
    ///    - guidanceColors: Colors to use for warnings, etc.
    ///    - openAppStore: Function to open up the App Store for the host app.
    /// - Returns: A view that will be opened when a software update is available from this service.
    func softwareUpdateView(bundleIdentifier: String,
                            currentVersion: String,
                            guidanceColors: GuidanceColors,
                            openAppStore: (() -> Void)?
    ) -> AnyView?
    
    /// Get the scenario(s) from the provided URL(s)
    ///
    ///  - Parameters:
    ///     - scenarioURLs: the URL(s) of the scenario(s) to get
    ///  - Returns: The scenario(s) matching the provided scenarioURLs
    func getScenarios(from scenarioURLs: [URL]) -> [LoopScenario]
    
    /// Called right before Loop resets UserDefaults and Documents storage
    /// Use this to store any temp values that need to be restored after a reset occurs
    func loopWillReset()
    
    /// Called right after Loop resets UserDefaults and Documents storage
    /// Use this to restore any values that were cached before a reset occurred
    func loopDidReset()
    
    /// Initializes the support with the previously-serialized state.
    ///
    /// - Parameters:
    ///     - rawState: The previously-serialized state of the support.
    init?(rawState: RawStateValue)

    /// The current, serializable state of the support.
    var rawState: RawStateValue { get }
 
    /// A delegate for SupportUI to use (see `SupportUIDelegate`).
    var delegate: SupportUIDelegate? { get set }
    
    var showsDeleteTestDataUI: Bool { get }
    
    var deviceIdentifierWhitelist: DeviceWhitelist { get }
}

extension SupportUI {    
    public var deviceIdentifierWhitelist: DeviceWhitelist {
        DeviceWhitelist()
    }
    
    public var showsDeleteTestDataUI: Bool {
        true
    }
}
