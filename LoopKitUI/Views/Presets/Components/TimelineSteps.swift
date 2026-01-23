//
//  TimelineSteps.swift
//  Loop
//
//  Created by Cameron Ingham on 8/27/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI

@resultBuilder
public struct TimelineBuilder {
    public static func buildBlock(_ components: TimelineStep...) -> [TimelineStep] {
        components
    }
}

public protocol TimelineStyle {
    var iconSize: Double { get }
    var baseIconPadding: Double { get }
    var iconTint: Color { get }
    var iconBackgroundColor: Color { get }
    var lineWidth: Double { get }
    var stepSpacing: Double { get }
    var stepSeparatorColor: Color { get }
    var titleFont: Font { get }
    var titleColor: Color { get }
    var subtitleFont: Font { get }
    var subtitleColor: Color { get }
}

public extension TimelineStyle {
    var iconSize: Double { 32 }
    var baseIconPadding: Double { 6 }
    var iconTint: Color { .accentColor }
    var iconBackgroundColor: Color { iconTint.opacity(0.1) }
    var lineWidth: Double { 4 }
    var stepSpacing: Double { 24 }
    var stepSeparatorColor: Color { iconTint.opacity(0.1) }
    var titleFont: Font { .body.weight(.semibold) }
    var titleColor: Color { .primary }
    var subtitleFont: Font { .subheadline }
    var subtitleColor: Color { .primary }
}

public struct DefaultTimelineStyle: TimelineStyle {}

public extension TimelineStyle where Self == DefaultTimelineStyle {
    static var `default`: DefaultTimelineStyle { DefaultTimelineStyle() }
}

public struct TimelineStep {
    let symbol: Image
    let symbolInset: Double
    let title: Text
    let subtitle: Text
    
    public init(symbol: Image, symbolInset: Double = 0, title: Text, subtitle: Text) {
        self.symbol = symbol
        self.symbolInset = symbolInset
        self.title = title
        self.subtitle = subtitle
    }
}

public struct Timeline: View {
    private let steps: [TimelineStep]
    
    private var style: TimelineStyle = DefaultTimelineStyle()

    init(steps: [TimelineStep]) {
        self.steps = steps
    }
    
    public init(@TimelineBuilder _ steps: () -> [TimelineStep]) {
        self.steps = steps()
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(steps.indices, id: \.self) { index in
                let step = steps[index]
                
                ZStack(alignment: .leading) {
                    GeometryReader { proxy in
                        style.stepSeparatorColor
                            .frame(width: style.lineWidth)
                            .padding(.top, index == 0 ? proxy.size.height / 2 : 0)
                            .padding(.bottom, index == steps.count - 1 ? proxy.size.height / 2 : 0)
                            .padding(.leading, style.iconSize / 2 - style.lineWidth / 2)
                            .mask {
                                InverseCircleMask(diameter: style.iconSize)
                                    .fill(Color(UIColor.systemBackground), style: FillStyle(eoFill: true))
                            }
                    }
                    
                    HStack(spacing: 12) {
                        step.symbol
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(style.iconTint)
                            .padding(style.baseIconPadding + step.symbolInset)
                            .frame(width: style.iconSize, height: style.iconSize)
                            .background(
                                Circle()
                                    .fill(style.iconBackgroundColor)
                            )
                        
                        VStack(alignment: .leading) {
                            step.title
                                .font(style.titleFont)
                                .foregroundStyle(style.titleColor)
                            
                            step.subtitle
                                .font(style.subtitleFont)
                                .foregroundStyle(style.subtitleColor)
                        }
                    }
                }
                
                if index < steps.count - 1 {
                    style.stepSeparatorColor
                        .frame(width: style.lineWidth, height: style.stepSpacing)
                        .padding(.leading, style.iconSize / 2 - style.lineWidth / 2)
                }
            }
        }
    }
    
    public func style(_ style: TimelineStyle) -> Timeline {
        var copy = self
        copy.style = style
        return copy
    }
}

private struct InverseCircleMask: Shape {
    
    let diameter: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Fills all available space
        path.addRect(rect)
        
        // Creates a hole in the middle with the specified diameter
        let hole = CGRect(
            x: 0,
            y: (rect.height - diameter) / 2,
            width: diameter,
            height: diameter
        )
        
        // Cuts the hole out of the path
        path.addEllipse(in: hole)
        
        return path
    }
}
