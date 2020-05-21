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
    var fractionalValuesByWhole: [Double: [Double]]
    var usageContext: UsageContext

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
        let fractionalValuesByWhole = selectableValues.reduce(into: [:], { fractionalValuesByWhole, selectableValue in
            fractionalValuesByWhole[selectableValue.whole, default: []].append(selectableValue.fraction)
        })

        self._whole = Binding(
            get: { doubleValue.wrappedValue.whole },
            set: { newValue in
                if newValue == guardrail.absoluteBounds.upperBound.doubleValue(for: unit) {
                    doubleValue.wrappedValue = newValue
                } else {
                    doubleValue.wrappedValue = newValue
                        + doubleValue.wrappedValue.fraction.truncating(toOneOf: fractionalValuesByWhole[newValue]!)
                }
            }
        )
        self._fraction = Binding(
            get: { doubleValue.wrappedValue.fraction.roundedToNearest(of: fractionalValuesByWhole[doubleValue.wrappedValue.whole]!) },
            set: { doubleValue.wrappedValue = doubleValue.wrappedValue.whole + $0 }
        )
        self.unit = unit
        self.guardrail = guardrail
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
                stride: HKQuantity(unit: unit, doubleValue: 1),
                guardrail: guardrail,
                formatter: Self.wholeFormatter,
                isUnitLabelVisible: false
            )
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

    /// The maximum number of decimal places supported by the picker.
    private var maximumSupportedPrecision: Int { 3 }

    private var fractionalFormatter: NumberFormatter {
        // Mutate the shared instance to avoid extra allocations.
        Self.fractionalFormatter.minimumFractionDigits = fractionalValuesByWhole[whole]!
            .lazy
            .map { Decimal($0) }
            .deltaScale(boundedBy: maximumSupportedPrecision)
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
