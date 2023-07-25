//
//  Environment+Colors.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-07-29.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit

private struct ColorPaletteKey: EnvironmentKey {
    static let defaultValue: LoopUIColorPalette = LoopUIColorPalette(guidanceColors: GuidanceColorsKey.defaultValue,
                                                                     carbTintColor: CarbTintColorKey.defaultValue,
                                                                     glucoseTintColor: GlucoseTintColorKey.defaultValue,
                                                                     insulinTintColor: InsulinTintColorKey.defaultValue,
                                                                     loopStatusColorPalette: LoopStatusColorPaletteKey.defaultValue,
                                                                     chartColorPalette: ChartColorPaletteKey.defaultValue)
}

public extension EnvironmentValues {
    var colorPalette: LoopUIColorPalette {
        get { self[ColorPaletteKey.self] }
        set { self[ColorPaletteKey.self] = newValue }
    }
}

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

private struct LoopStatusColorPaletteKey: EnvironmentKey {
    static let defaultValue: StateColorPalette = StateColorPalette(unknown: .systemGray4,
                                                                   normal: .green,
                                                                   warning: .yellow,
                                                                   error: .red)
}

public extension EnvironmentValues {
    var loopStatusColorPalette: StateColorPalette {
        get { self[LoopStatusColorPaletteKey.self] }
        set { self[LoopStatusColorPaletteKey.self] = newValue }
    }
}

private struct ChartColorPaletteKey: EnvironmentKey {
    static let defaultValue: ChartColorPalette = ChartColorPalette(axisLine: .clear,
                                                                   axisLabel: .secondaryLabel,
                                                                   grid: .systemGray3,
                                                                   glucoseTint: .systemTeal,
                                                                   insulinTint: .orange,
                                                                   carbTint: .systemGreen)
}

public extension EnvironmentValues {
    var chartColorPalette: ChartColorPalette {
        get { self[ChartColorPaletteKey.self] }
        set { self[ChartColorPaletteKey.self] = newValue }
    }
}
