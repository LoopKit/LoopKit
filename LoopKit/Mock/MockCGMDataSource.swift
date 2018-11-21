//
//  MockCGMDataSource.swift
//  LoopKit
//
//  Created by Michael Pangburn on 11/23/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import HealthKit


public struct MockCGMDataSource {
    public enum Model {
        public typealias SineCurveParameters = (baseGlucose: HKQuantity, amplitude: HKQuantity, period: TimeInterval, referenceDate: Date)

        case constant(_ glucose: HKQuantity)
        case sineCurve(parameters: SineCurveParameters)
        case noData
    }

    public struct Effects {
        public typealias RandomOutlier = (chance: Double, delta: HKQuantity)

        public var delay: TimeInterval?
        public var glucoseNoise: HKQuantity?
        public var randomLowOutlier: RandomOutlier?
        public var randomHighOutlier: RandomOutlier?
        public var randomErrorChance: Double?

        public init(
            delay: TimeInterval? = nil,
            glucoseNoise: HKQuantity? = nil,
            randomLowOutlier: RandomOutlier? = nil,
            randomHighOutlier: RandomOutlier? = nil,
            randomErrorChance: Double? = nil
        ) {
            self.delay = delay
            self.glucoseNoise = glucoseNoise
            self.randomLowOutlier = randomLowOutlier
            self.randomHighOutlier = randomHighOutlier
            self.randomErrorChance = randomErrorChance
        }
    }

    static let device = HKDevice(
        name: MockCGMManager.managerIdentifier,
        manufacturer: nil,
        model: nil,
        hardwareVersion: nil,
        firmwareVersion: nil,
        softwareVersion: String(LoopKitVersionNumber),
        localIdentifier: nil,
        udiDeviceIdentifier: nil
    )

    public let model: Model
    public let effects: Effects
    private let glucoseProvider: MockGlucoseProvider

    public init(model: Model, effects: Effects = .init()) {
        self.model = model
        self.effects = effects
        self.glucoseProvider = MockGlucoseProvider(model: model, effects: effects)
    }

    func fetchNewData(_ completion: @escaping (CGMResult) -> Void) {
        return glucoseProvider.fetchData(at: Date(), completion: completion)
    }
}
