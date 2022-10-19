//
//  UAMSettings.swift
//  LoopKit
//
//  Created by Anna Quinlan on 10/19/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

public struct UAMSettings {
    /// Minimum grams of unannounced carbs that must be detected
    public static let carbThreshold: Double = 40 // grams
    /// Minimum threshold for glucose rise over the detection window
    static let glucoseRiseThreshold = 2.0 // mg/dL/m
    /// Minimum time from now that must have passed for the meal to be detected
    public static let minRecency = TimeInterval(minutes: 30)
    /// Maximum time from now that a meal can be detected
    public static let maxRecency = TimeInterval(hours: 2)
}
