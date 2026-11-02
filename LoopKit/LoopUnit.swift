//
//  File.swift
//  LoopKit
//
//  Created by Cameron Ingham on 11/8/24.
//

import Foundation

let UnitMolarMassBloodGlucose = 180.1558800000541
let UnitMolarMassBloodGlucoseDivisible = UnitMolarMassBloodGlucose / 10

public enum LoopUnit: Sendable, CaseIterable {
    case gram
    case gramsPerUnit
    case internationalUnit
    case internationalUnitsPerHour
    case milligramsPerDeciliter
    case milligramsPerDeciliterPerSecond
    case milligramsPerDeciliterPerMinute
    case milligramsPerDeciliterPerInternationalUnit
    case millimolesPerLiter
    case millimolesPerLiterPerSecond
    case millimolesPerLiterPerMinute
    case millimolesPerLiterPerInternationalUnit
    case percent
    case hour
    case minute
    case second
    
    public init(from string: String) {
        self = LoopUnit.allCases.first(where: { $0.unitString == string }) ?? .gram
    }
    
    public func conversionFactor(toUnit: LoopUnit) -> Double? {
        switch (self, toUnit) {
        case (.gram, .gram),
             (.gramsPerUnit, .gramsPerUnit),
             (.internationalUnit, .internationalUnit),
             (.internationalUnitsPerHour, .internationalUnitsPerHour),
             (.milligramsPerDeciliter, .milligramsPerDeciliter),
             (.milligramsPerDeciliterPerSecond, .milligramsPerDeciliterPerSecond),
             (.milligramsPerDeciliterPerMinute, .milligramsPerDeciliterPerMinute),
             (.milligramsPerDeciliterPerInternationalUnit, .milligramsPerDeciliterPerInternationalUnit),
             (.millimolesPerLiter, .millimolesPerLiter),
             (.millimolesPerLiterPerSecond, .millimolesPerLiterPerSecond),
             (.millimolesPerLiterPerMinute, .millimolesPerLiterPerMinute),
             (.millimolesPerLiterPerInternationalUnit, .millimolesPerLiterPerInternationalUnit),
             (.percent, .percent),
             (.hour, .hour),
             (.minute, .minute),
             (.second, .second):
            return 1
        case (.milligramsPerDeciliterPerSecond, .milligramsPerDeciliterPerMinute),
             (.millimolesPerLiterPerSecond, .millimolesPerLiterPerMinute):
            return 60
        case (.second, .minute),
             (.minute, .hour):
            return 1/60
        case (.milligramsPerDeciliterPerMinute, .milligramsPerDeciliterPerSecond),
             (.millimolesPerLiterPerMinute, .millimolesPerLiterPerSecond):
            return 1/60
        case (.minute, .second),
             (.hour, .minute):
            return 60
        case (.second, .hour):
            return 1/3600
        case (.hour, .second):
            return 3600
        case (.milligramsPerDeciliter, .millimolesPerLiter),
             (.milligramsPerDeciliterPerSecond, .millimolesPerLiterPerSecond),
             (.milligramsPerDeciliterPerMinute, .millimolesPerLiterPerMinute),
             (.milligramsPerDeciliterPerInternationalUnit, .millimolesPerLiterPerInternationalUnit):
            return 1/UnitMolarMassBloodGlucoseDivisible
        case (.milligramsPerDeciliterPerSecond, .millimolesPerLiterPerMinute):
            // Rate: per-second -> per-minute multiplies by 60 (opposite of a duration conversion)
            return 1/UnitMolarMassBloodGlucoseDivisible * 60
        case (.milligramsPerDeciliterPerMinute, .millimolesPerLiterPerSecond):
            return 1/UnitMolarMassBloodGlucoseDivisible / 60
        case (.millimolesPerLiter, .milligramsPerDeciliter),
             (.millimolesPerLiterPerSecond, .milligramsPerDeciliterPerSecond),
             (.millimolesPerLiterPerMinute, .milligramsPerDeciliterPerMinute),
             (.millimolesPerLiterPerInternationalUnit, .milligramsPerDeciliterPerInternationalUnit):
            return UnitMolarMassBloodGlucoseDivisible
        case (.millimolesPerLiterPerSecond, .milligramsPerDeciliterPerMinute):
            return UnitMolarMassBloodGlucoseDivisible * 60
        case (.millimolesPerLiterPerMinute, .milligramsPerDeciliterPerSecond):
            return UnitMolarMassBloodGlucoseDivisible / 60
        case (.gram, _),
             (.gramsPerUnit, _),
             (.internationalUnit, _),
             (.internationalUnitsPerHour, _),
             (.milligramsPerDeciliter, _),
             (.milligramsPerDeciliterPerSecond, _),
             (.milligramsPerDeciliterPerMinute, _),
             (.milligramsPerDeciliterPerInternationalUnit, _),
             (.millimolesPerLiter, _),
             (.millimolesPerLiterPerSecond, _),
             (.millimolesPerLiterPerMinute, _),
             (.millimolesPerLiterPerInternationalUnit, _),
             (.percent, _),
             (.hour, _),
             (.minute, _),
             (.second, _):
            return nil
        default:
            fatalError()
        }
    }
    
    public var unitString: String {
        switch self {
        case .gram:
            return "g"
        case .gramsPerUnit:
            return "g/IU"
        case .percent:
            return "%"
        case .milligramsPerDeciliter:
            return "mg/dL"
        case .milligramsPerDeciliterPerSecond:
            return "mg/dL·s"
        case .milligramsPerDeciliterPerMinute:
            return "mg/min·dL"
        case .milligramsPerDeciliterPerInternationalUnit:
            return "mg/dL·IU"
        case .millimolesPerLiter:
            return "mmol<\(UnitMolarMassBloodGlucose)>/L"
        case .millimolesPerLiterPerSecond:
            return "mmol<\(UnitMolarMassBloodGlucose)>/L·s"
        case .millimolesPerLiterPerMinute:
            return "mmol<\(UnitMolarMassBloodGlucose)>/min·L"
        case .millimolesPerLiterPerInternationalUnit:
            return "mmol<\(UnitMolarMassBloodGlucose)>/L·IU"
        case .internationalUnit:
            return "IU"
        case .internationalUnitsPerHour:
            return "IU/hr"
        case .hour:
            return "hr"
        case .minute:
            return "min"
        case .second:
            return "s"
        }
    }
    
    public var localizedShortUnitString: String {
        switch self {
        case .millimolesPerLiter: return NSLocalizedString("mmol/L", comment: "The short unit display string for millimoles of glucose per liter")
        case .milligramsPerDeciliter: return NSLocalizedString("mg/dL", comment: "The short unit display string for milligrams of glucose per decilter")
        case .internationalUnit: return NSLocalizedString("U", comment: "The short unit display string for international units of insulin")
        case .gram: return NSLocalizedString("g", comment: "The short unit display string for grams")
        default: return String(describing: self)
        }
    }
    
    public func unitDivided(by unit: LoopUnit) -> LoopUnit {
        switch self {
        case .milligramsPerDeciliter:
            switch unit {
            case .minute:
                return .milligramsPerDeciliterPerMinute
            case .second:
                return .milligramsPerDeciliterPerSecond
            case .internationalUnit:
                return .milligramsPerDeciliterPerInternationalUnit
            default:
                fatalError("\(self.localizedShortUnitString) is not divisible by \(unit.localizedShortUnitString)")
            }
        case .millimolesPerLiter:
            switch unit {
            case .minute:
                return .millimolesPerLiterPerMinute
            case .second:
                return .millimolesPerLiterPerSecond
            case .internationalUnit:
                return .millimolesPerLiterPerInternationalUnit
            default:
                fatalError("\(self.localizedShortUnitString) is not divisible by \(unit.localizedShortUnitString)")
            }
        case .internationalUnit:
            switch unit {
            case .hour:
                return .internationalUnitsPerHour
            default:
                fatalError("\(self.localizedShortUnitString) is not divisible by \(unit.localizedShortUnitString)")
            }
        case .gram:
            switch unit {
            case .internationalUnit:
                return .gramsPerUnit
            default:
                fatalError("\(self.localizedShortUnitString) is not divisible by \(unit.localizedShortUnitString)")
            }
        default:
            fatalError("\(self.localizedShortUnitString) is not divisible by \(unit.localizedShortUnitString)")
        }
    }
}
