//
//  PresentationMode.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 7/21/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

/// Represents the different modes that settings screens might be represented in
public enum PresentationMode {
    /// Presentation is in the onboarding acceptance flow
    case acceptanceFlow
    /// Presentation is under the settings ("gear icon") screen
    case settings
    /// Presentation is under the old UIKit (legacy) settings screen
    case legacySettings
}
