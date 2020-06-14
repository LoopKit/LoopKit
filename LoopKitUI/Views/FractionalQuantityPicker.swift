//
//  FractionalQuantityPicker.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 5/18/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit


/// Enables selecting the whole and fractional parts of an HKQuantity value in independent pickers.
struct FractionalQuantityPicker: View {
    enum UsageContext: Equatable {
        /// This picker is one component of a larger multi-component picker (e.g. a schedule item picker).
        case component(availableWidth: CGFloat)

        /// This picker operates independently.
        case independent
    }

    @Binding var whole: Double
    @Binding var fraction: Double
    var unit: HKUnit
    var guardrail: Guardrail<HKQuantity>
    var selectableWholeValues: [Double]
    var fractionalValuesByWhole: [Double: [Double]]
    var usageContext: UsageContext

    /// The maximum number of decimal places supported by the picker.
    private static var maximumSupportedPrecision: Int { 3 }

    private static let wholeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumIntegerDigits = 1
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private static let fractionalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.decimalSeparator = ""
        formatter.maximumIntegerDigits = 0
        return formatter
    }()

    init(
        value: Binding<HKQuantity>,
        unit: HKUnit,
        guardrail: Guardrail<HKQuantity>,
        selectableValues: [Double],
        usageContext: UsageContext = .independent
    ) {
        let doubleValue = value.doubleValue(for: unit)
        let (selectableWholeValues, fractionalValuesByWhole): ([Double], [Double: [Double]]) = selectableValues.reduce(into: ([], [:])) { pair, selectableValue in
            let whole = selectableValue.whole
            if pair.0.last != whole {
                pair.0.append(whole)
            }
            pair.1[whole, default: []].append(selectableValue.fraction)
        }

        self._whole = Binding(
            get: { doubleValue.wrappedValue.whole },
            set: { newWholeValue in
                // If the new whole value supports the same fractional value, keep it; otherwise, truncate.
                let supportedFractionValues = fractionalValuesByWhole[newWholeValue]!
                let currentFraction = doubleValue.wrappedValue.fraction
                let nearestSupportedFraction = currentFraction.roundedToNearest(of: supportedFractionValues)
                let newFractionValue: Double
                if abs(nearestSupportedFraction - currentFraction) <= pow(10.0, Double(-Self.maximumSupportedPrecision)) {
                    newFractionValue = nearestSupportedFraction
                } else {
                    newFractionValue = currentFraction.truncating(toOneOf: supportedFractionValues)
                }
                let newDoubleValue = newWholeValue + newFractionValue
                let maxValue = guardrail.absoluteBounds.upperBound.doubleValue(for: unit)
                doubleValue.wrappedValue = min(newDoubleValue, maxValue)
            }
        )
        self._fraction = Binding(
            get: { doubleValue.wrappedValue.fraction.roundedToNearest(of: fractionalValuesByWhole[doubleValue.wrappedValue.whole]!) },
            set: { newFractionValue in
                let newDoubleValue = doubleValue.wrappedValue.whole + newFractionValue
                let minValue = guardrail.absoluteBounds.lowerBound.doubleValue(for: unit)
                doubleValue.wrappedValue = max(newDoubleValue, minValue)
            }
        )
        self.unit = unit
        self.guardrail = guardrail
        self.selectableWholeValues = selectableWholeValues
        self.fractionalValuesByWhole = fractionalValuesByWhole
        self.usageContext = usageContext
    }

    var body: some View {
        switch usageContext {
        case .component(availableWidth: let availableWidth):
            return AnyView(body(availableWidth: availableWidth))
        case .independent:
            return AnyView(
                GeometryReader { geometry in
                    HStack {
                        Spacer()
                        self.body(availableWidth: geometry.size.width)
                        Spacer()
                    }
                }
                .frame(height: 216)
            )
        }
    }

    func body(availableWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            QuantityPicker(
                value: $whole.withUnit(unit),
                unit: unit,
                guardrail: wholeGuardrail,
                selectableValues: selectableWholeValues,
                formatter: Self.wholeFormatter,
                isUnitLabelVisible: false
            )
            // Ensure whole picker color updates when fraction updates
            .id(whole + fraction)
            .frame(width: availableWidth / 3.5)
            .overlay(
                Text(separator)
                    .foregroundColor(Color(.secondaryLabel))
                    .offset(x: spacing + separatorWidth),
                alignment: .trailing
            )
            .padding(.leading, usageContext == .independent ? unitLabelWidth + spacing : 0)
            .padding(.trailing, spacing + separatorWidth + spacing)
            .clipped()

            QuantityPicker(
                value: $fraction.withUnit(unit),
                unit: unit,
                guardrail: fractionalGuardrail,
                selectableValues: fractionalValuesByWhole[whole]!,
                formatter: fractionalFormatter
            )
            // Ensure fractional picker values update when whole value updates
            .id(whole + fraction)
            .frame(width: availableWidth / 3.5)
            .padding(.trailing, spacing + unitLabelWidth)
            .clipped()
        }
    }

    private var wholeGuardrail: Guardrail<HKQuantity> {
        // Whether or not the whole value should be colored as 'out of range' depends only on the fraction value.
        let lowerRecommendedBound = guardrail.recommendedBounds.lowerBound.doubleValue(for: unit)
        if fraction < lowerRecommendedBound.fraction {
            return guardrail
        } else {
            // Shift the lower bounds down one 'whole' value.
            // Note: this shift doesn't affect which values are selectable, only the coloration of the selectable values.
            // For example, if the real guardrail's lower bound is 3.00, the whole '3' should be colored only when '00' is selected
            // in the fractional picker, regardless of the current whole value.
            return Guardrail(
                absoluteBounds: HKQuantity(unit: unit, doubleValue: guardrail.absoluteBounds.lowerBound.doubleValue(for: unit) - 1)...guardrail.absoluteBounds.upperBound,
                recommendedBounds: HKQuantity(unit: unit, doubleValue: lowerRecommendedBound - 1)...guardrail.recommendedBounds.upperBound
            )
        }
    }

    private var fractionalGuardrail: Guardrail<HKQuantity>? {
        let lowerAbsoluteBound = guardrail.absoluteBounds.lowerBound.doubleValue(for: unit)
        let upperAbsoluteBound = guardrail.absoluteBounds.upperBound.doubleValue(for: unit)
        let lowerRecommendedBound = guardrail.recommendedBounds.lowerBound.doubleValue(for: unit)
        let upperRecommendedBound = guardrail.recommendedBounds.upperBound.doubleValue(for: unit)

        // Thresholds for use in defining recommended bounds,
        // to simplify the expression of (e.g.) "all selectable values are smaller than recommended",
        // resulting in 'warning'-colored picker values.
        let valueTooSmallToSelect: Double = -1
        let valueTooLargeToSelect: Double = 1

        switch whole {
        case lowerAbsoluteBound.whole:
            let fractionalLowerRecommendedBound = lowerAbsoluteBound.whole == lowerRecommendedBound.whole
                ? fractionalValuesByWhole[whole]!.first! + pow(10.0, -Double(Self.maximumSupportedPrecision))
                : valueTooLargeToSelect
            return Guardrail(
                absoluteBounds: fractionalValuesByWhole[whole]!.first!...valueTooLargeToSelect,
                recommendedBounds: fractionalLowerRecommendedBound...valueTooLargeToSelect,
                unit: unit
            )
        case ..<lowerRecommendedBound.whole:
            return Guardrail(
                absoluteBounds: valueTooSmallToSelect...valueTooLargeToSelect,
                recommendedBounds: valueTooLargeToSelect...valueTooLargeToSelect,
                unit: unit
            )
        case lowerRecommendedBound.whole:
            let fractionalLowerRecommendedBound = lowerRecommendedBound.fraction + pow(10.0, -Double(Self.maximumSupportedPrecision))
            return Guardrail(
                absoluteBounds: valueTooSmallToSelect...valueTooLargeToSelect,
                recommendedBounds: fractionalLowerRecommendedBound...valueTooLargeToSelect,
                unit: unit
            )
        case ..<upperRecommendedBound.whole:
            return nil
        case upperRecommendedBound.whole:
            return Guardrail(
                absoluteBounds: valueTooSmallToSelect...valueTooLargeToSelect,
                recommendedBounds: valueTooSmallToSelect...upperRecommendedBound.fraction,
                unit: unit
            )
        case ..<upperAbsoluteBound.whole:
            return Guardrail(
                absoluteBounds: valueTooSmallToSelect...valueTooLargeToSelect,
                recommendedBounds: valueTooSmallToSelect...valueTooSmallToSelect,
                unit: unit
            )
        case upperAbsoluteBound.whole:
            return Guardrail(
                absoluteBounds: valueTooSmallToSelect...fractionalValuesByWhole[whole]!.last!,
                recommendedBounds: valueTooSmallToSelect...valueTooSmallToSelect,
                unit: unit
            )
        default:
            assertionFailure("unreachable")
            return nil
        }
    }

    private var fractionalFormatter: NumberFormatter {
        // Mutate the shared instance to avoid extra allocations.
        Self.fractionalFormatter.minimumFractionDigits = fractionalValuesByWhole[whole]!
            .lazy
            .map { Decimal($0) }
            .deltaScale(boundedBy: Self.maximumSupportedPrecision)
        return Self.fractionalFormatter
    }

    var separator: String { "." }

    var separatorWidth: CGFloat {
        let attributedSeparator = NSAttributedString(
            string: separator,
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
        )

        return attributedSeparator.size().width
    }

    var spacing: CGFloat { 8 }

    var unitLabelWidth: CGFloat {
        let attributedUnitString = NSAttributedString(
            string: unit.shortLocalizedUnitString(),
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
        )

        return attributedUnitString.size().width
    }
}

fileprivate extension FloatingPoint {
    var whole: Self { modf(self).0 }
    var fraction: Self { modf(self).1 }

    /// Precondition: - `supportedValues` is sorted in ascending order.
    func roundedToNearest(of supportedValues: [Self]) -> Self {
        guard !supportedValues.isEmpty else {
            return self
        }

        let splitPoint = supportedValues.partitioningIndex(where: { $0 > self })
        switch splitPoint {
        case supportedValues.startIndex:
            return supportedValues.first!
        case supportedValues.endIndex:
            return supportedValues.last!
        default:
            let (lesser, greater) = (supportedValues[splitPoint - 1], supportedValues[splitPoint])
            return (self - lesser) <= (greater - self) ? lesser : greater
        }
    }

    /// Precondition: - `supportedValues` is sorted in ascending order.
    func truncating(toOneOf supportedValues: [Self]) -> Self {
        guard !supportedValues.isEmpty else {
            return self
        }

        let splitPoint = supportedValues.partitioningIndex(where: { $0 > self })
        return splitPoint == supportedValues.startIndex
            ? supportedValues.first!
            : supportedValues[splitPoint - 1]
    }
}

fileprivate extension Decimal {
    func rounded(toPlaces scale: Int, roundingMode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
        var result = Decimal()
        var localCopy = self
        NSDecimalRound(&result, &localCopy, scale, roundingMode)
        return result
    }
}

fileprivate extension Collection where Element == Decimal {
    /// Returns the maximum number of decimal places necessary to meaningfully distinguish between adjacent values.
    /// - Precondition: The collection is sorted in ascending order.
    func deltaScale(boundedBy maxScale: Int) -> Int {
        let roundedToMaxScale = lazy.map { $0.rounded(toPlaces: maxScale) }
        guard let maxDelta = roundedToMaxScale.adjacentPairs().map(-).map(abs).max() else {
            return 0
        }

        return abs(Swift.min(maxDelta.exponent, 0))
    }
}
