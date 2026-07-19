//
//  ChartPointsContextFillLayer.swift
//  Loop
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import Charts
import SwiftUI


/// Shared scaffolding for the Loop charts: applies the shared X-axis, the generated Y-axis,
/// Loop's chart colors, margins matching the previous SwiftCharts layout, and the
/// touch-highlight overlay driven by an external gesture recognizer.
struct LoopChartView<Content: ChartContent>: View {
    let generationContext: ChartGenerationContext
    let yAxisValues: [Double]
    var yAxisLabelProvider: (Double) -> String
    var hidesAxes: Bool
    var highlight: ChartHighlightSpec?
    @ObservedObject var highlightModel: ChartHighlightModel
    @ChartContentBuilder var content: () -> Content

    init(
        generationContext: ChartGenerationContext,
        yAxisValues: [Double],
        yAxisLabelProvider: @escaping (Double) -> String = { NumberFormatter.chartAxis.string(from: NSNumber(value: $0)) ?? "\($0)" },
        hidesAxes: Bool = false,
        highlight: ChartHighlightSpec? = nil,
        highlightModel: ChartHighlightModel,
        @ChartContentBuilder content: @escaping () -> Content
    ) {
        self.generationContext = generationContext
        self.yAxisValues = yAxisValues
        self.yAxisLabelProvider = yAxisLabelProvider
        self.hidesAxes = hidesAxes
        self.highlight = highlight
        self.highlightModel = highlightModel
        self.content = content
    }

    private var settings: ChartSettings {
        generationContext.chartSettings
    }

    private var colors: ChartColorPalette {
        generationContext.colors
    }

    private var xAxisModel: ChartXAxisModel {
        generationContext.xAxisModel
    }

    private var yDomain: ClosedRange<Double> {
        guard let min = yAxisValues.first, let max = yAxisValues.last, min < max else {
            return 0...1
        }
        return min...max
    }

    private var gridLineStyle: StrokeStyle {
        StrokeStyle(lineWidth: 0.3)
    }

    var body: some View {
        Chart {
            content()
        }
        .chartXScale(domain: xAxisModel.startDate...xAxisModel.endDate)
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: xAxisModel.labelDates) { value in
                AxisGridLine(stroke: gridLineStyle)
                    .foregroundStyle(Color(colors.grid))
                if !hidesAxes {
                    AxisValueLabel(anchor: .top, verticalSpacing: settings.labelsToAxisSpacingX) {
                        if let date = value.as(Date.self) {
                            // The label's leading edge anchors at the tick; a fixed-width
                            // centered frame shifted back by half its width centers the
                            // text on the gridline.
                            Text(xAxisModel.axisLabelFormatter.string(from: date))
                                .font(Font(generationContext.axisLabelFont))
                                .foregroundColor(Color(colors.axisLabel))
                                .frame(width: 64, alignment: .center)
                                .offset(x: -36)
                        }
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: yAxisValues) { value in
                AxisGridLine(stroke: gridLineStyle)
                    .foregroundStyle(Color(colors.grid))
                // The label space is reserved even when the labels are hidden so the
                // supplemental strip's gridlines align with the chart below it.
                AxisValueLabel(horizontalSpacing: settings.labelsToAxisSpacingY) {
                    if hidesAxes {
                        Color.clear.frame(width: generationContext.labelsWidthY, height: 1)
                    } else if let scalar = value.as(Double.self) {
                        Text(yAxisLabelProvider(scalar))
                            .font(Font(generationContext.axisLabelFont))
                            .foregroundColor(Color(colors.axisLabel))
                            .frame(width: generationContext.labelsWidthY, alignment: .trailing)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .chartOverlay { proxy in
            highlightOverlay(proxy: proxy)
        }
        .padding(EdgeInsets(top: settings.top, leading: settings.leading, bottom: settings.bottom, trailing: settings.trailing))
    }

    // MARK: - Touch highlight

    private struct HighlightedPoint {
        let point: ChartPoint
        let position: CGPoint
    }

    @ViewBuilder
    private func highlightOverlay(proxy: ChartProxy) -> some View {
        GeometryReader { geo in
            ZStack {
                if let spec = highlight,
                   let touchLocation = highlightModel.touchLocation,
                   let highlighted = nearestPoint(in: spec, to: touchLocation, proxy: proxy, geo: geo)
                {
                    let plotFrame = geo[proxy.plotAreaFrame]
                    let tint = highlighted.point.overrideColor ?? spec.tintColor
                    let pointSize = highlighted.point.overrideHighlightPointSize ?? ChartHighlightSpec.defaultPointSize

                    // Cover the axis labels while interacting, showing only the touched time
                    let axisBandTop = plotFrame.maxY + 1
                    let axisBandHeight = max(geo.size.height - axisBandTop, 0)
                    Rectangle()
                        .fill(Color(UIColor.systemBackground))
                        .frame(width: geo.size.width, height: axisBandHeight)
                        .position(x: geo.size.width / 2, y: axisBandTop + axisBandHeight / 2)

                    if let date = highlighted.point.date {
                        Text(xAxisModel.highlightLabelFormatter.string(from: date))
                            .font(Font(generationContext.axisLabelFont))
                            .foregroundColor(Color(colors.axisLabel))
                            .position(x: highlighted.position.x, y: axisBandTop + axisBandHeight / 2)
                    }

                    // The highlighted point
                    Circle()
                        .fill(Color(tint))
                        .opacity(0.5)
                        .frame(width: pointSize, height: pointSize)
                        .position(x: highlighted.position.x, y: highlighted.position.y + spec.highlightPointOffsetY)

                    // The value label above the chart: emphasized value with lighter unit
                    let labelY = plotFrame.minY - 21 - generationContext.highlightLabelOffsetY
                    let labelText = highlighted.point.y.label
                    let estimatedHalfWidth = max(24, CGFloat(labelText.count) * 5.6)
                    let labelX = min(max(highlighted.position.x, plotFrame.minX + estimatedHalfWidth), plotFrame.maxX - estimatedHalfWidth)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(highlighted.point.y.valueLabel ?? labelText)
                            .font(.system(size: 20, weight: .semibold))
                        if let unit = highlighted.point.y.unitLabel {
                            Text(unit)
                                .font(.system(size: 15, weight: .regular))
                        }
                    }
                    .foregroundColor(Color(tint))
                    .position(x: labelX, y: labelY)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: highlightModel.touchLocation == nil)
        }
    }

    private func nearestPoint(in spec: ChartHighlightSpec, to touchLocation: CGPoint, proxy: ChartProxy, geo: GeometryProxy) -> HighlightedPoint? {
        let plotFrame = geo[proxy.plotAreaFrame]
        let touchX = touchLocation.x - settings.leading

        var nearest: HighlightedPoint?
        var nearestDistance = CGFloat.greatestFiniteMagnitude

        for point in spec.points {
            guard let date = point.date,
                  let xPosition = proxy.position(forX: date),
                  let yPosition = proxy.position(forY: point.y.scalar)
            else {
                continue
            }

            let position = CGPoint(x: plotFrame.minX + xPosition, y: plotFrame.minY + yPosition)
            let distance = abs(position.x - touchX)

            if distance < nearestDistance {
                nearestDistance = distance
                nearest = HighlightedPoint(point: point, position: position)
            }
        }

        return nearest
    }
}


extension NumberFormatter {
    static var chartAxis: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter
    }
}
