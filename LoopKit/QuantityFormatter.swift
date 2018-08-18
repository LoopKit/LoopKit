//
//  QuantityFormatter.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit


/// Formats unit quantities as localized strings
open class QuantityFormatter {

    public init() {
    }

    /// The unit style determines how the unit strings are abbreviated, and spacing between the value and unit
    open var unitStyle: Formatter.UnitStyle = .medium {
        didSet {
            if hasMeasurementFormatter {
                measurementFormatter.unitStyle = unitStyle
            }

            if hasMassFormatter {
                massFormatter.unitStyle = unitStyle
            }
        }
    }

    open var locale: Locale = Locale.current {
        didSet {
            if hasNumberFormatter {
                numberFormatter.locale = locale
            }

            if hasMeasurementFormatter {
                measurementFormatter.locale = locale
            }
        }
    }

    /// Updates `numberFormatter` configuration for the specified unit
    ///
    /// - Parameter unit: The unit
    open func setPreferredNumberFormatter(for unit: HKUnit) {
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumFractionDigits = unit.preferredFractionDigits
        numberFormatter.maximumFractionDigits = unit.preferredFractionDigits
    }

    private var hasNumberFormatter = false

    /// The formatter used for the quantity values
    open private(set) lazy var numberFormatter: NumberFormatter = {
        hasNumberFormatter = true

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = self.locale
        return formatter
    }()

    private var hasMeasurementFormatter = false

    /// MeasurementFormatter is used for gram measurements, mg/dL units, and mmol/L units.
    /// It does not properly handle glucose measurements, as it changes unit scales: 100 mg/dL -> 1 g/L
    private lazy var measurementFormatter: MeasurementFormatter = {
        hasMeasurementFormatter = true

        let formatter = MeasurementFormatter()
        formatter.unitOptions = [.providedUnit]
        formatter.numberFormatter = self.numberFormatter
        formatter.locale = self.locale
        formatter.unitStyle = self.unitStyle
        return formatter
    }()

    private var hasMassFormatter = false

    /// MassFormatter properly creates unit strings for grams in .short/.medium style as "g", where MeasurementFormatter uses "gram"/"grams"
    private lazy var massFormatter: MassFormatter = {
        hasMassFormatter = true

        let formatter = MassFormatter()
        formatter.numberFormatter = self.numberFormatter
        formatter.unitStyle = self.unitStyle
        return formatter
    }()

    /// Formats a quantity and unit as a localized string
    ///
    /// - Parameters:
    ///   - quantity: The quantity
    ///   - unit: The value. An exception is thrown if `quantity` is not compatible with the unit.
    /// - Returns: A localized string, or nil if `numberFormatter` is unable to format the quantity value
    open func string(from quantity: HKQuantity, for unit: HKUnit) -> String? {
        let value = quantity.doubleValue(for: unit)

        if let foundationUnit = unit.foundationUnit, unit.usesMeasurementFormatterForMeasurement {
            return measurementFormatter.string(from: Measurement(value: value, unit: foundationUnit))
        }

        return numberFormatter.string(from: value, unit: string(from: unit), style: unitStyle)
    }

    /// Formats a unit as a localized string
    ///
    /// - Parameters:
    ///   - unit: The unit
    ///   - value: An optional value for determining the plurality of the unit string
    /// - Returns: A string for the unit. If no localization entry is available, the unlocalized `unitString` is returned.
    open func string(from unit: HKUnit, forValue value: Double = 10) -> String {
        if let string = unit.localizedUnitString(in: unitStyle) {
            return string
        }

        if unit.usesMassFormatterForUnitString {
            return massFormatter.unitString(fromValue: value, unit: HKUnit.massFormatterUnit(from: unit))
        }

        if let foundationUnit = unit.foundationUnit {
            return measurementFormatter.string(from: foundationUnit)
        }

        // Fallback, unlocalized
        return unit.unitString
    }
}


private extension HKUnit {
    var usesMassFormatterForUnitString: Bool {
        return self == .gram()
    }

    var usesMeasurementFormatterForMeasurement: Bool {
        return self == .gram()
    }

    var preferredFractionDigits: Int {
        if self == HKUnit.millimolesPerLiter {
            return 1
        } else {
            return 0
        }
    }

    func localizedUnitString(in style: Formatter.UnitStyle) -> String? {
        if self == .internationalUnit() {
            switch style {
            case .short, .medium:
                return LocalizedString("U", comment: "The short unit display string for international units of insulin")
            case .long:
                return LocalizedString("Units", comment: "The long unit display string for international units of insulin")
            }
        }

        if self == HKUnit.millimolesPerLiter {
            switch style {
            case .short, .medium:
                return LocalizedString("mmol/L", comment: "The short unit display string for millimoles of glucose per liter")
            case .long:
                break  // Fallback to the MeasurementFormatter localization
            }
        }

        return nil
    }
}
