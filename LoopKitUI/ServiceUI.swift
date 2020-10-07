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

public protocol ServiceUI: Service {
    
    /// The image for this type of service.
    static var image: UIImage? { get }

    /// Provides a view controller to create and configure a new service, if needed.
    ///
    /// - Returns: A view controller to create and configure a new service.
    static func setupViewController(currentTherapySettings: TherapySettings, preferredGlucoseUnit: HKUnit, chartColors: ChartColorPalette, carbTintColor: Color, glucoseTintColor: Color, guidanceColors: GuidanceColors, insulinTintColor: Color) -> (UIViewController & ServiceSetupNotifying & CompletionNotifying)?

    /// Provides a view controller to configure an existing service.
    ///
    /// - Returns: A view controller to configure an existing service.
    func settingsViewController(currentTherapySettings: TherapySettings, preferredGlucoseUnit: HKUnit, chartColors: ChartColorPalette, carbTintColor: Color, glucoseTintColor: Color, guidanceColors: GuidanceColors, insulinTintColor: Color) -> (UIViewController & ServiceSettingsNotifying & CompletionNotifying)

}

public extension ServiceUI {

    // Default
    static var image: UIImage? { nil }
    
    var image: UIImage? { return type(of: self).image }
}
