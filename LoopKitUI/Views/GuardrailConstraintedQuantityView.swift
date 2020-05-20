//
//  GuardrailConstraintedQuantityView.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/24/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit


public struct GuardrailConstrainedQuantityView: View {
    var value: HKQuantity
    var unit: HKUnit
    var guardrail: Guardrail<HKQuantity>
    var isEditing: Bool
    var formatter: NumberFormatter
    var iconSpacing: CGFloat
    var isUnitLabelVisible: Bool
    var forceDisableAnimations: Bool

    @State private var hasAppeared = false

    public init(
        value: HKQuantity,
        unit: HKUnit,
        guardrail: Guardrail<HKQuantity>,
        isEditing: Bool,
        iconSpacing: CGFloat = 8,
        isUnitLabelVisible: Bool = true,
        forceDisableAnimations: Bool = false
    ) {
        self.value = value
        self.unit = unit
        self.guardrail = guardrail
        self.isEditing = isEditing
        self.iconSpacing = iconSpacing
        self.formatter = {
            let quantityFormatter = QuantityFormatter()
            quantityFormatter.setPreferredNumberFormatter(for: unit)
            return quantityFormatter.numberFormatter
        }()
        self.isUnitLabelVisible = isUnitLabelVisible
        self.forceDisableAnimations = forceDisableAnimations
    }

    public var body: some View {
        HStack {
            HStack(spacing: iconSpacing) {
                if guardrail.classification(for: value) != .withinRecommendedRange {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(warningColor)
                        .transition(.springInDisappear)
                }

                Text(formatter.string(from: value.doubleValue(for: unit)) ?? "\(value.doubleValue(for: unit))")
                    .foregroundColor(warningColor)
            }

            if isUnitLabelVisible {
                Text(unit.shortLocalizedUnitString())
                    .foregroundColor(Color(.secondaryLabel))
            }
        }
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
        switch guardrail.classification(for: value) {
        case .withinRecommendedRange:
            return isEditing ? .accentColor : .primary
        case .outsideRecommendedRange(let threshold):
            switch threshold {
            case .minimum, .maximum:
                return .severeWarning
            case .belowRecommended, .aboveRecommended:
                return .warning
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
