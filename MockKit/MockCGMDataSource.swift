//
//  MockCGMDataSource.swift
//  LoopKit
//
//  Created by Michael Pangburn on 11/23/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import HealthKit
import LoopKit


public struct MockCGMDataSource {
    public enum Model {
        public typealias SineCurveParameters = (baseGlucose: HKQuantity, amplitude: HKQuantity, period: TimeInterval, referenceDate: Date)

        case constant(_ glucose: HKQuantity)
        case sineCurve(parameters: SineCurveParameters)
        case noData
        case signalLoss
        case unreliableData
        
        public var isValidSession: Bool {
            switch self {
            case .noData:
                return false
            default:
                return true
            }
        }
    }

    public struct Effects {
        public typealias RandomOutlier = (chance: Double, delta: HKQuantity)

        public var glucoseNoise: HKQuantity?
        public var randomLowOutlier: RandomOutlier?
        public var randomHighOutlier: RandomOutlier?
        public var randomErrorChance: Double?

        public init(
            glucoseNoise: HKQuantity? = nil,
            randomLowOutlier: RandomOutlier? = nil,
            randomHighOutlier: RandomOutlier? = nil,
            randomErrorChance: Double? = nil
        ) {
            self.glucoseNoise = glucoseNoise
            self.randomLowOutlier = randomLowOutlier
            self.randomHighOutlier = randomHighOutlier
            self.randomErrorChance = randomErrorChance
        }
    }

    static let device = HKDevice(
        name: "MockCGMManager",
        manufacturer: "LoopKit",
        model: "MockCGMManager",
        hardwareVersion: nil,
        firmwareVersion: nil,
        softwareVersion: "1.0",
        localIdentifier: nil,
        udiDeviceIdentifier: nil
    )

    public var model: Model {
        didSet {
            glucoseProvider = MockGlucoseProvider(model: model, effects: effects)
        }
    }

    public var effects: Effects {
        didSet {
            glucoseProvider = MockGlucoseProvider(model: model, effects: effects)
        }
    }

    private var glucoseProvider: MockGlucoseProvider

    private var lastFetchedData = Locked(Date.distantPast)

    public var dataPointFrequency: MeasurementFrequency
    
    public var isValidSession: Bool {
        return model.isValidSession
    }
    
    public init(
        model: Model,
        effects: Effects = .init(),
        dataPointFrequency: MeasurementFrequency = .normal
    ) {
        self.model = model
        self.effects = effects
        self.glucoseProvider = MockGlucoseProvider(model: model, effects: effects)
        self.dataPointFrequency = dataPointFrequency
    }

    func fetchNewData(_ completion: @escaping (CGMReadingResult) -> Void) {
        let now = Date()
        // Give 5% wiggle room for producing data points
        let bufferedFrequency = dataPointFrequency.frequency - 0.05 * dataPointFrequency.frequency
        if now.timeIntervalSince(lastFetchedData.value) < bufferedFrequency {
            completion(.noData)
            return
        }

        lastFetchedData.value = now
        glucoseProvider.fetchData(at: now, completion: completion)
    }

    func backfillData(from interval: DateInterval, completion: @escaping (CGMReadingResult) -> Void) {
        lastFetchedData.value = interval.end
        let request = MockGlucoseProvider.BackfillRequest(datingBack: interval.duration, dataPointFrequency: dataPointFrequency.frequency)
        glucoseProvider.backfill(request, endingAt: interval.end, completion: completion)
    }
}

extension MockCGMDataSource: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        guard
            let model = (rawValue["model"] as? Model.RawValue).flatMap(Model.init(rawValue:)),
            let effects = (rawValue["effects"] as? Effects.RawValue).flatMap(Effects.init(rawValue:)),
            let dataPointFrequency = (rawValue["dataPointFrequency"] as? MeasurementFrequency.RawValue).flatMap(MeasurementFrequency.init(rawValue:))
        else {
            return nil
        }

        self.init(model: model, effects: effects, dataPointFrequency: dataPointFrequency)
    }

    public var rawValue: RawValue {
        return [
            "model": model.rawValue,
            "effects": effects.rawValue,
            "dataPointFrequency": dataPointFrequency.rawValue
        ]
    }
}

extension MockCGMDataSource.Model: RawRepresentable {
    public typealias RawValue = [String: Any]

    private enum Kind: String {
        case constant
        case sineCurve
        case noData
        case signalLoss
        case unreliableData
    }

    private static let unit = HKUnit.milligramsPerDeciliter

    public init?(rawValue: RawValue) {
        guard
            let kindRawValue = rawValue["kind"] as? Kind.RawValue,
            let kind = Kind(rawValue: kindRawValue)
        else {
            return nil
        }

        let unit = MockCGMDataSource.Model.unit
        func glucose(forKey key: String) -> HKQuantity? {
            guard let doubleValue = rawValue[key] as? Double else {
                return nil
            }
            return HKQuantity(unit: unit, doubleValue: doubleValue)
        }

        switch kind {
        case .constant:
            guard let quantity = glucose(forKey: "quantity") else {
                return nil
            }
            self = .constant(quantity)
        case .sineCurve:
            guard
                let baseGlucose = glucose(forKey: "baseGlucose"),
                let amplitude = glucose(forKey: "amplitude"),
                let period = rawValue["period"] as? TimeInterval,
                let referenceDateSeconds = rawValue["referenceDate"] as? TimeInterval
            else {
                return nil
            }

            let referenceDate = Date(timeIntervalSince1970: referenceDateSeconds)
            self = .sineCurve(parameters: (baseGlucose: baseGlucose, amplitude: amplitude, period: period, referenceDate: referenceDate))
        case .noData:
            self = .noData
        case .signalLoss:
            self = .signalLoss
        case .unreliableData:
            self = .unreliableData
        }
    }

    public var rawValue: RawValue {
        var rawValue: RawValue = ["kind": kind.rawValue]

        let unit = MockCGMDataSource.Model.unit
        switch self {
        case .constant(let quantity):
            rawValue["quantity"] = quantity.doubleValue(for: unit)
        case .sineCurve(parameters: (baseGlucose: let baseGlucose, amplitude: let amplitude, period: let period, referenceDate: let referenceDate)):
            rawValue["baseGlucose"] = baseGlucose.doubleValue(for: unit)
            rawValue["amplitude"] = amplitude.doubleValue(for: unit)
            rawValue["period"] = period
            rawValue["referenceDate"] = referenceDate.timeIntervalSince1970
        case .noData, .signalLoss, .unreliableData:
            break
        }

        return rawValue
    }

    private var kind: Kind {
        switch self {
        case .constant:
            return .constant
        case .sineCurve:
            return .sineCurve
        case .noData:
            return .noData
        case .signalLoss:
            return .signalLoss
        case .unreliableData:
            return .unreliableData
        }
    }
}

extension MockCGMDataSource.Effects: RawRepresentable {
    public typealias RawValue = [String: Any]

    private static let unit = HKUnit.milligramsPerDeciliter

    public init?(rawValue: RawValue) {
        self.init()

        let unit = MockCGMDataSource.Effects.unit
        func randomOutlier(forKey key: String) -> RandomOutlier? {
            guard
                let outlier = rawValue[key] as? [String: Double],
                let chance = outlier["chance"],
                let delta = outlier["delta"]
            else {
                return nil
            }

            return (chance: chance, delta: HKQuantity(unit: unit, doubleValue: delta))
        }

        if let glucoseNoise = rawValue["glucoseNoise"] as? Double {
            self.glucoseNoise = HKQuantity(unit: unit, doubleValue: glucoseNoise)
        }

        self.randomLowOutlier = randomOutlier(forKey: "randomLowOutlier")
        self.randomHighOutlier = randomOutlier(forKey: "randomHighOutlier")
        self.randomErrorChance = rawValue["randomErrorChance"] as? Double
    }

    public var rawValue: RawValue {
        var rawValue: RawValue = [:]

        let unit = MockCGMDataSource.Effects.unit
        func insertOutlier(_ outlier: RandomOutlier, forKey key: String) {
            rawValue[key] = [
                "chance": outlier.chance,
                "delta": outlier.delta.doubleValue(for: unit)
            ]
        }

        if let glucoseNoise = glucoseNoise {
            rawValue["glucoseNoise"] = glucoseNoise.doubleValue(for: unit)
        }

        if let randomLowOutlier = randomLowOutlier {
            insertOutlier(randomLowOutlier, forKey: "randomLowOutlier")
        }

        if let randomHighOutlier = randomHighOutlier {
            insertOutlier(randomHighOutlier, forKey: "randomHighOutlier")
        }

        if let randomErrorChance = randomErrorChance {
            rawValue["randomErrorChance"] = randomErrorChance
        }

        return rawValue
    }
}

extension MockCGMDataSource: CustomDebugStringConvertible {
    public var debugDescription: String {
        return """
        ## MockCGMDataSource
        * model: \(model)
        * effects: \(effects)
        """
    }
}

public enum MeasurementFrequency: Int, CaseIterable {
    case normal
    case fast
    case faster

    public var frequency: TimeInterval {
        switch self {
        case .normal:
            return TimeInterval(5*60)
        case .fast:
            return TimeInterval(60)
        case .faster:
            return TimeInterval(5)
        }
    }
    public var localizedDescription: String {
        switch self {
        case .normal:
            return "5 minutes"
        case .fast:
            return "1 minute"
        case .faster:
            return "5 seconds"
        }
    }
}
