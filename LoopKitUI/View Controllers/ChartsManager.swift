//
//  Chart.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/19/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import LoopKit
import UIKit


/// The shared X-axis model for a stack of charts, so all charts in a set align vertically.
public struct ChartXAxisModel {
    /// The earliest date displayed on the axis
    public let startDate: Date

    /// The latest date displayed on the axis
    public let endDate: Date

    /// The dates at which visible axis labels and vertical gridlines are drawn (interior whole hours)
    public let labelDates: [Date]

    /// Formats the axis labels (e.g. "3 PM")
    public let axisLabelFormatter: DateFormatter

    /// Formats the highlight-overlay time label (e.g. "3:45 PM")
    public let highlightLabelFormatter: DateFormatter
}


/// Everything a chart needs, besides its own data, to render itself.
public struct ChartGenerationContext {
    public let xAxisModel: ChartXAxisModel
    public let colors: ChartColorPalette
    public let chartSettings: ChartSettings
    public let axisLabelFont: UIFont
    public let labelsWidthY: CGFloat
    public let gestureRecognizer: UIGestureRecognizer?
    public let traitCollection: UITraitCollection
    public let highlightLabelOffsetY: CGFloat
}


open class ChartsManager {

    private lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        let dateFormat = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: Locale.current)!
        let isAmPmTimeFormat = dateFormat.firstIndex(of: "a") != nil
        formatter.dateFormat = isAmPmTimeFormat
            ? "h a"
            : "H:mm"
        return formatter
    }()

    private lazy var highlightTimeFormatter = DateFormatter(timeStyle: .short)

    public init(
        colors: ChartColorPalette,
        settings: ChartSettings,
        axisLabelFont: UIFont = .systemFont(ofSize: 14), // caption1, but hard-coded until axis can scale with type preference
        charts: [ChartProviding],
        traitCollection: UITraitCollection
    ) {
        self.colors = colors
        self.chartSettings = settings
        self.axisLabelFont = axisLabelFont
        self.charts = charts
        self.traitCollection = traitCollection
        self.chartsCache = Array(repeating: nil, count: charts.count)
    }

    // MARK: - Configuration

    private let colors: ChartColorPalette

    private let chartSettings: ChartSettings

    private let axisLabelFont: UIFont

    private let labelsWidthY: CGFloat = 30

    public let charts: [ChartProviding]

    /// The amount of horizontal space reserved for fixed margins
    public var fixedHorizontalMargin: CGFloat {
        return chartSettings.leading + chartSettings.trailing + labelsWidthY + chartSettings.labelsToAxisSpacingY
    }

    public var gestureRecognizer: UIGestureRecognizer?

    // MARK: - UITraitEnvironment

    public var traitCollection: UITraitCollection

    public func didReceiveMemoryWarning() {

        for chart in charts {
            chart.didReceiveMemoryWarning()
        }

        xAxisModel = nil
    }

    // MARK: - Data

    /// The earliest date on the X-axis
    public var startDate = Date() {
        didSet {
            if startDate != oldValue {
                xAxisModel = nil

                // Set a new minimum end date
                endDate = startDate.addingTimeInterval(.hours(3))
            }
        }
    }

    /// The latest date on the X-axis
    private var endDate = Date() {
        didSet {
            if endDate != oldValue {
                xAxisModel = nil
            }
        }
    }

    /// The latest allowed date on the X-axis
    public var maxEndDate = Date.distantFuture {
        didSet {
            endDate = min(endDate, maxEndDate)
        }
    }

    /// Updates the endDate using a new candidate date
    ///
    /// Dates are rounded up to the next hour.
    ///
    /// - Parameter date: The new candidate date
    public func updateEndDate(_ date: Date) {
        if date > endDate {
            let components = DateComponents(minute: 0)
            endDate = min(
                maxEndDate,
                Calendar.current.nextDate(
                    after: date,
                    matching: components,
                    matchingPolicy: .strict,
                    direction: .forward
                ) ?? date
            )
        }
    }

    // MARK: - State

    /// The dates of the current shared X-axis labels, exposed for accessibility identifiers
    public static var xAxisAccessibilityIDs: [Date]?

    private var xAxisModel: ChartXAxisModel? {
        didSet {
            ChartsManager.xAxisAccessibilityIDs = xAxisModel?.labelDates
            chartsCache.replaceAllElements(with: nil)
        }
    }

    private var chartsCache: [(view: UIView, frame: CGRect)?]

    // MARK: - Generators

    public func chart(atIndex index: Int, frame: CGRect, highlightLabelOffsetY: CGFloat = 0) -> UIView? {
        if let cached = chartsCache[index], cached.frame != frame {
            chartsCache[index] = nil
        }

        if chartsCache[index] == nil, let xAxisModel = xAxisModel {
            let context = ChartGenerationContext(
                xAxisModel: xAxisModel,
                colors: colors,
                chartSettings: chartSettings,
                axisLabelFont: axisLabelFont,
                labelsWidthY: labelsWidthY,
                gestureRecognizer: gestureRecognizer,
                traitCollection: traitCollection,
                highlightLabelOffsetY: highlightLabelOffsetY
            )
            chartsCache[index] = (view: charts[index].generate(withFrame: frame, context: context), frame: frame)
        }

        return chartsCache[index]?.view
    }

    public func invalidateChart(atIndex index: Int) {
        chartsCache[index] = nil
    }

    // MARK: - Shared Axis

    private func generateXAxisValues() {
        if let endDate = charts.compactMap({ $0.endDate }).max() {
            updateEndDate(endDate)
        }

        let calendar = Calendar.current

        // Axis bounds are aligned to whole hours containing the date range
        let axisStart = calendar.dateInterval(of: .hour, for: startDate)?.start ?? startDate
        var axisEnd = calendar.dateInterval(of: .hour, for: endDate)?.start ?? endDate
        if axisEnd < endDate {
            axisEnd = axisEnd.addingTimeInterval(.hours(1))
        }

        // Labels and gridlines are drawn at interior whole hours; the first and last
        // axis values are hidden, matching the previous SwiftCharts behavior.
        var labelDates: [Date] = []
        var date = axisStart.addingTimeInterval(.hours(1))
        while date < axisEnd {
            labelDates.append(date)
            date = date.addingTimeInterval(.hours(1))
        }

        xAxisModel = ChartXAxisModel(
            startDate: axisStart,
            endDate: axisEnd,
            labelDates: labelDates,
            axisLabelFormatter: timeFormatter,
            highlightLabelFormatter: highlightTimeFormatter
        )
    }

    /// Runs any necessary steps before rendering charts
    public func prerender() {
        if xAxisModel == nil {
            generateXAxisValues()
        }
    }
}

fileprivate extension Array {
    mutating func replaceAllElements(with element: Element) {
        self = Array(repeating: element, count: count)
    }
}

public protocol ChartProviding: AnyObject {
    /// Instructs the chart to clear its non-critical resources like caches
    func didReceiveMemoryWarning()

    /// The last date represented in the chart data
    var endDate: Date? { get }

    /// Creates a chart view from the current data
    ///
    /// - Returns: A new chart view
    func generate(withFrame frame: CGRect, context: ChartGenerationContext) -> UIView
}
