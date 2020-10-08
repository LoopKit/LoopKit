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

    public convenience init(for unit: HKUnit) {
        self.init()
        setPreferredNumberFormatter(for: unit)
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
        numberFormatter.maximumFractionDigits = unit.maxFractionDigits
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
    ///   - unit: The unit. An exception is thrown if `quantity` is not compatible with the unit.
    ///   - includeUnit: Whether or not to include the unit in the returned string
    /// - Returns: A localized string, or nil if `numberFormatter` is unable to format the quantity value
    open func string(from quantity: HKQuantity, for unit: HKUnit, includeUnit: Bool = true) -> String? {
        let value = quantity.doubleValue(for: unit)

        if !includeUnit {
            return numberFormatter.string(from: value)
        }

        if let foundationUnit = unit.foundationUnit, unit.usesMeasurementFormatterForMeasurement {
            return measurementFormatter.string(from: Measurement(value: value, unit: foundationUnit))
        }        
        
        return numberFormatter.string(from: value, unit: string(from: unit, forValue: value), style: unitStyle)
    }

    /// Formats a unit as a localized string
    ///
    /// - Parameters:
    ///   - unit: The unit
    ///   - value: An optional value for determining the plurality of the unit string
    /// - Returns: A string for the unit. If no localization entry is available, the unlocalized `unitString` is returned.
    open func string(from unit: HKUnit, forValue value: Double = 10) -> String {
        if let string = unit.localizedUnitString(in: unitStyle, singular: abs(1.0 - value) < .ulpOfOne) {
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


public extension HKUnit {
    var usesMassFormatterForUnitString: Bool {
        return self == .gram()
    }

    var usesMeasurementFormatterForMeasurement: Bool {
        return self == .gram()
    }

    var preferredFractionDigits: Int {
        if self == HKUnit.millimolesPerLiter || self == HKUnit.millimolesPerLiter.unitDivided(by: .internationalUnit()) {
            return 1
        } else {
            return 0
        }
    }

    var maxFractionDigits: Int {
        switch self {
        case .internationalUnit(), .internationalUnitsPerHour:
            return 3
        case HKUnit.gram().unitDivided(by: .internationalUnit()):
            return 2
        default:
            return preferredFractionDigits
        }
    }

    // Short localized unit string with unlocalized fallback
    func shortLocalizedUnitString() -> String {
        return localizedUnitString(in: .short) ?? unitString
    }

    func localizedUnitString(in style: Formatter.UnitStyle, singular: Bool = false) -> String? {
        if self == .internationalUnit() {
            switch style {
            case .short, .medium:
                return LocalizedString("U", comment: "The short unit display string for international units of insulin")
            case .long:
                fallthrough
            @unknown default:
                if singular {
                    return LocalizedString("Unit", comment: "The long unit display string for a singular international unit of insulin")
                } else {
                    return LocalizedString("Units", comment: "The long unit display string for international units of insulin")
                }
            }
        }

        if self == .internationalUnitsPerHour {
            switch style {
            case .short, .medium:
                return LocalizedString("U/hr", comment: "The short unit display string for international units of insulin per hour")
            case .long:
                fallthrough
            @unknown default:
                if singular {
                    return LocalizedString("Unit/hour", comment: "The long unit display string for a singular international unit of insulin per hour")
                } else {
                    return LocalizedString("Units/hour", comment: "The long unit display string for international units of insulin per hour")
                }
            }
        }

        if self == HKUnit.millimolesPerLiter {
            switch style {
            case .short, .medium:
                return LocalizedString("mmol/L", comment: "The short unit display string for millimoles per liter")
            case .long:
                break  // Fallback to the MeasurementFormatter localization
            @unknown default:
                break
            }
        }

        if self == HKUnit.milligramsPerDeciliter.unitDivided(by: HKUnit.internationalUnit()) {
            switch style {
            case .short, .medium:
                return LocalizedString("mg/dL/U", comment: "The short unit display string for milligrams per deciliter per U")
            case .long:
                break  // Fallback to the MeasurementFormatter localization
            @unknown default:
                break
            }
        }

        if self == HKUnit.millimolesPerLiter.unitDivided(by: HKUnit.internationalUnit()) {
            switch style {
            case .short, .medium:
                return LocalizedString("mmol/L/U", comment: "The short unit display string for millimoles per liter per U")
            case .long:
                break  // Fallback to the MeasurementFormatter localization
            @unknown default:
                break
            }
        }

        if self == HKUnit.gram().unitDivided(by: HKUnit.internationalUnit()) {
            switch style {
            case .short, .medium:
                return LocalizedString("g/U", comment: "The short unit display string for grams per U")
            case .long:
                fallthrough
            @unknown default:
                break  // Fallback to the MeasurementFormatter localization
            }
        }

        return nil
    }
}
