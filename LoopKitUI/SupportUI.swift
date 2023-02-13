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

public protocol SupportUIDelegate: AlertIssuer { }

public protocol SupportUI: AnyObject {
    typealias RawStateValue = [String: Any]

    /// The unique identifier of this type of support.
    static var supportIdentifier: String { get }

    /// Provides support menu item.
    ///
    /// - Parameters:
    ///   - supportInfoProvider: A provider of additional support information.
    ///   - urlHandler: A handler to open any URLs.
    /// - Returns: A view that will be used in a support menu for providing user support.
    func supportMenuItem(supportInfoProvider: SupportInfoProvider, urlHandler: @escaping (URL) -> Void) -> AnyView?

    /// Provides configuration menu items.
    ///
    /// - Parameters:
    ///   - supportInfoProvider: A provider of additional support information.
    ///   - urlHandler: A handler to open any URLs.
    /// - Returns: An array of views that will be added to the configuration section of settings.
    func configurationMenuItems() -> [AnyView]

    ///
    /// Check whether the given app version for the given `bundleIdentifier` needs an update.  Services should return their last result, if known.
    ///
    /// - Parameters:
    ///    - bundleIdentifier: The host app's `bundleIdentifier` (a.k.a. `CFBundleIdentifier`) string.
    ///    - currentVersion: The host app's current version (i.e. `CFBundleVersion`).
    ///    - completion: The completion function to call with any success result (or `nil` if not known) or failure.
    func checkVersion(bundleIdentifier: String, currentVersion: String, completion: @escaping (Result<VersionUpdate?, Error>) -> Void)
    
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

    /// Initializes the support with the previously-serialized state.
    ///
    /// - Parameters:
    ///     - rawState: The previously-serialized state of the support.
    init?(rawState: RawStateValue)

    /// The current, serializable state of the support.
    var rawState: RawStateValue { get }
 
    /// A delegate for SupportUI to use (see `SupportUIDelegate`).
    var delegate: SupportUIDelegate? { get set }
}

extension SupportUI {
    public var identifier: String {
        return Self.supportIdentifier
    }
}
