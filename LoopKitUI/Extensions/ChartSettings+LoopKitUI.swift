//
//  ChartSettings+LoopKitUI.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 7/20/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import CoreGraphics

/// Layout settings for the Loop charts.
///
/// This mirrors the subset of the third-party SwiftCharts `ChartSettings` type that Loop
/// used, so existing call sites continue to work after the Apple Swift Charts migration.
public struct ChartSettings {
    public var leading: CGFloat = 0
    public var top: CGFloat = 0
    public var trailing: CGFloat = 0
    public var bottom: CGFloat = 0
    public var labelsToAxisSpacingX: CGFloat = 5
    public var labelsToAxisSpacingY: CGFloat = 5
    public var axisTitleLabelsToLabelsSpacing: CGFloat = 5
    public var axisStrokeWidth: CGFloat = 1
    public var clipInnerFrame = true

    public init() {}
}


extension ChartSettings {
    static var `default`: ChartSettings {
        var settings = ChartSettings()
        settings.top = 12
        settings.bottom = 0
        settings.trailing = 8
        settings.axisTitleLabelsToLabelsSpacing = 0
        settings.labelsToAxisSpacingX = 6
        settings.clipInnerFrame = false
        return settings
    }
}
