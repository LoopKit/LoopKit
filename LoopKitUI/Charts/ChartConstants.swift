//
//  ChartConstants.swift
//  LoopUI
//
//  Created by Pete Schwamb on 10/16/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit
import SwiftCharts
import UIKit
import LoopKit
import LoopAlgorithm

public enum ChartConstants {
    public static let minimumChartWidthPerHour: CGFloat = 50

    public static let statusChartMinimumHistoryDisplay: TimeInterval = .hours(1)

    public static let glucoseChartDefaultDisplayBound =
        HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 100)...HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 175)

    public static let glucoseChartDefaultDisplayRangeWide =
        HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 60)...HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 200)

    public static let glucoseChartDefaultDisplayBoundClamped =
        HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 80)...HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 240)
}

public enum ChartDisplayOptions {
    public static var showsNowLine = false
}

/// A vertical line at the current time, when the now line is turned on.
func nowLineLayer(xAxisLayer: ChartAxisLayer, yAxisLayer: ChartAxisLayer, color: UIColor) -> ChartLayer? {
    guard ChartDisplayOptions.showsNowLine else { return nil }
    let now = ChartAxisValueDate(date: Date(), formatter: { _ in "" })
    let settings = ChartGuideLinesLayerSettings(linesColor: color, linesWidth: 1.0)
    return ChartGuideLinesForValuesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: settings, axisValuesX: [now], axisValuesY: [])
}
