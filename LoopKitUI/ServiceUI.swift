//
//  ServiceUI.swift
//  LoopKitUI
//
//  Created by Darin Krauss on 5/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit
import SwiftUI
import HealthKit

public protocol SupportInfoProvider {
    var pumpStatus: PumpManagerStatus? { get }
    var cgmDevice: HKDevice? { get }
    var localizedAppNameAndVersion: String { get }
    func generateIssueReport(completion: @escaping (String) -> Void)
}

public protocol ServiceUI: Service {
    
    /// The image for this type of service.
    static var image: UIImage? { get }
    
    /// Indicates whether this service provides onboarding (configuring therapy settings)
    static var providesOnboarding: Bool { get }

    /// Provides a view controller to create and configure a new service, if needed.
    ///
    /// - Returns: A view controller to create and configure a new service.
    static func setupViewController(currentTherapySettings: TherapySettings, preferredGlucoseUnit: HKUnit, chartColors: ChartColorPalette, carbTintColor: Color, glucoseTintColor: Color, guidanceColors: GuidanceColors, insulinTintColor: Color) -> (UIViewController & ServiceSetupNotifying & CompletionNotifying)?

    /// Provides a view controller to configure an existing service.
    ///
    /// - Returns: A view controller to configure an existing service.
    func settingsViewController(currentTherapySettings: TherapySettings, preferredGlucoseUnit: HKUnit, chartColors: ChartColorPalette, carbTintColor: Color, glucoseTintColor: Color, guidanceColors: GuidanceColors, insulinTintColor: Color) -> (UIViewController & ServiceSettingsNotifying & CompletionNotifying)
    
    /// Provides a view controller to configure an existing service.
    ///
    /// - Returns: A view that will be used in a support menu for providing user support
    func supportMenuItem(supportInfoProvider: SupportInfoProvider, urlHandler: @escaping (URL) -> Void) -> AnyView?
}

public extension ServiceUI {
    var image: UIImage? { return type(of: self).image }
}
