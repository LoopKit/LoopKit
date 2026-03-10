//
//  GuardrailConstraintedQuantityView.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/24/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopAlgorithm


public struct GuardrailConstrainedQuantityView: View {
    @Environment(\.guidanceColors) var guidanceColors
    var value: LoopQuantity?
    var unit: LoopUnit
    var guardrail: Guardrail<LoopQuantity>
    var isEditing: Bool
    var isSupportedValue: Bool
    var formatter: NumberFormatter
    var iconSpacing: CGFloat
    var isUnitLabelVisible: Bool
    var forceDisableAnimations: Bool

    @State private var hasAppeared = false

    public init(
        value: LoopQuantity?,
        unit: LoopUnit,
        guardrail: Guardrail<LoopQuantity>,
        isEditing: Bool,
        isSupportedValue: Bool = true,
        iconSpacing: CGFloat = 8,
        isUnitLabelVisible: Bool = true,
        forceDisableAnimations: Bool = false
    ) {
        self.value = value
        self.unit = unit
        self.guardrail = guardrail
        self.isEditing = isEditing
        self.isSupportedValue = isSupportedValue
        self.iconSpacing = iconSpacing
        self.formatter = {
            let quantityFormatter = QuantityFormatter(for: unit)
            return quantityFormatter.numberFormatter
        }()
        self.isUnitLabelVisible = isUnitLabelVisible
        self.forceDisableAnimations = forceDisableAnimations
    }

    public var body: some View {
        HStack {
            HStack(spacing: iconSpacing) {
                if value != nil {
                    if guardrail.classification(for: value!) != .withinRecommendedRange {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(warningColor)
                            .transition(.springInDisappear)
                            .accessibilityIdentifier(accessibilityIdentifier)
                    }

                    Text(formatter.string(from: value!.doubleValue(for: unit)) ?? "\(value!.doubleValue(for: unit))")
                        .foregroundColor(warningColor)
                        .fixedSize(horizontal: true, vertical: false)
                        .accessibilityIdentifier("text_setGlucoseValue")
                } else {
                    Text("–")
                        .foregroundColor(.secondary)
                }
            }

            if isUnitLabelVisible {
                Text(unit.shortLocalizedUnitString())
                    .foregroundColor(Color(.secondaryLabel))
            }
        }
        .accessibilityElement(children: .combine)
        .onAppear { self.hasAppeared = true }
        .animation(animation)
    }

    private var animation: Animation? {
        // A conditional implicit animation seems to behave funky on first appearance.
        // Disable animations until the view has appeared.
        if forceDisableAnimations || !hasAppeared {
            return nil
        }

        // While editing, the text width is liable to change, which can cause a slow-feeling animation
        // of the guardrail warning icon. Disable animations while editing.
        return isEditing ? nil : .default
    }

    private var warningColor: Color {
        guard let value = value else {
            return .primary
        }
        
        guard isSupportedValue else { return guidanceColors.critical }

        switch guardrail.classification(for: value) {
        case .withinRecommendedRange:
            return isEditing ? .accentColor : guidanceColors.acceptable
        case .outsideRecommendedRange(let threshold):
            switch threshold {
            case .minimum, .maximum:
                return guidanceColors.critical
            case .belowWarning, .aboveWarning:
                return guidanceColors.critical
            case .belowRecommended, .aboveRecommended:
                return guidanceColors.warning
            }
        }
    }
    
    private var accessibilityIdentifier: String {
        guard let value = value else {
            return "noWarningImage"
        }
        

        switch guardrail.classification(for: value) {
        case .withinRecommendedRange:
            return "noWarningImage"
        case .outsideRecommendedRange(let threshold):
            switch threshold {
            case .minimum, .maximum:
                return "imageNextToText_warningTriangleRed"
            case .belowWarning, .aboveWarning:
                return "imageNextToText_warningTriangleRed"
            case .belowRecommended, .aboveRecommended:
                return "imageNextToText_warningTriangleOrange"
            }
        }
    }
}

fileprivate extension AnyTransition {
    static let springInDisappear = asymmetric(
        insertion: AnyTransition.scale.animation(.spring(dampingFraction: 0.5)),
        removal: .identity
    )
}
