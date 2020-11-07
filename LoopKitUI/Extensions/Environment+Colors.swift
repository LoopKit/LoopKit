//
//  Environment+Colors.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-07-29.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

private struct GuidanceColorsKey: EnvironmentKey {
    static let defaultValue: GuidanceColors = GuidanceColors()
}

public extension EnvironmentValues {
    var guidanceColors: GuidanceColors {
        get { self[GuidanceColorsKey.self] }
        set { self[GuidanceColorsKey.self] = newValue }
    }
}

private struct CarbTintColorKey: EnvironmentKey {
    static let defaultValue: Color = .green
}

public extension EnvironmentValues {
    var carbTintColor: Color {
        get { self[CarbTintColorKey.self] }
        set { self[CarbTintColorKey.self] = newValue }
    }
}

private struct GlucoseTintColorKey: EnvironmentKey {
    static let defaultValue: Color = Color(.systemTeal)
}

public extension EnvironmentValues {
    var glucoseTintColor: Color {
        get { self[GlucoseTintColorKey.self] }
        set { self[GlucoseTintColorKey.self] = newValue }
    }
}

private struct InsulinTintColorKey: EnvironmentKey {
    static let defaultValue: Color = .orange
}

public extension EnvironmentValues {
    var insulinTintColor: Color {
        get { self[InsulinTintColorKey.self] }
        set { self[InsulinTintColorKey.self] = newValue }
    }
}

private struct LightInsulinTintColorKey: EnvironmentKey {
    static let defaultValue: UIColor = .lightenedInsulin
}

public extension EnvironmentValues {
    var lightenedInsulinTintColor: UIColor {
        get { self[LightInsulinTintColorKey.self] }
        set { self[LightInsulinTintColorKey.self] = newValue }
    }
}

private struct DarkInsulinTintColorKey: EnvironmentKey {
    static let defaultValue: UIColor = .darkenedInsulin
}

public extension EnvironmentValues {
    var darkenedInsulinTintColor: UIColor {
        get { self[DarkInsulinTintColorKey.self] }
        set { self[DarkInsulinTintColorKey.self] = newValue }
    }
}
