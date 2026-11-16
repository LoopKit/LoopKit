//
//  StoredHealthSample.swift
//  LoopKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public struct StoredHealthSample: Equatable, Sendable {
    public enum Kind: String, CaseIterable, Sendable {
        case heartRate
        case restingHeartRate
        case walkingHeartRateAverage
        case heartRateRecoveryOneMinute
        case heartRateVariabilitySDNN
        case vo2Max
        case activeEnergyBurned
        case stepCount
        case physicalEffort
        case bodyMass

        public var quantityType: HKQuantityType {
            switch self {
            case .heartRate: HKQuantityType(.heartRate)
            case .restingHeartRate: HKQuantityType(.restingHeartRate)
            case .walkingHeartRateAverage: HKQuantityType(.walkingHeartRateAverage)
            case .heartRateRecoveryOneMinute: HKQuantityType(.heartRateRecoveryOneMinute)
            case .heartRateVariabilitySDNN: HKQuantityType(.heartRateVariabilitySDNN)
            case .vo2Max: HKQuantityType(.vo2Max)
            case .activeEnergyBurned: HKQuantityType(.activeEnergyBurned)
            case .stepCount: HKQuantityType(.stepCount)
            case .physicalEffort: HKQuantityType(.physicalEffort)
            case .bodyMass: HKQuantityType(.bodyMass)
            }
        }

        public var unit: HKUnit {
            switch self {
            case .heartRate, .restingHeartRate, .walkingHeartRateAverage, .heartRateRecoveryOneMinute: .count().unitDivided(by: .minute())
            case .heartRateVariabilitySDNN: .secondUnit(with: .milli)
            case .vo2Max: HKUnit(from: "ml/kg*min")
            case .activeEnergyBurned: .kilocalorie()
            case .stepCount: .count()
            case .physicalEffort: HKUnit(from: "kcal/hr*kg")
            case .bodyMass: .gramUnit(with: .kilo)
            }
        }

        public var unitString: String {
            switch self {
            case .heartRate, .restingHeartRate, .walkingHeartRateAverage, .heartRateRecoveryOneMinute: "bpm"
            case .heartRateVariabilitySDNN: "ms"
            case .vo2Max: "mL/kg/min"
            case .activeEnergyBurned: "kcal"
            case .stepCount: "count"
            case .physicalEffort: "kcal/hr/kg"
            case .bodyMass: "kg"
            }
        }
    }

    public enum MotionContext: String, Sendable {
        case sedentary
        case active
    }

    public let uuid: UUID
    public let kind: Kind
    public let startDate: Date
    public let endDate: Date
    /// In `kind.unit`.
    public let value: Double
    public let motionContext: MotionContext?
    public let source: StoredWorkout.Source
    public let device: StoredWorkout.Device?

    public init(uuid: UUID, kind: Kind, startDate: Date, endDate: Date, value: Double, motionContext: MotionContext? = nil, source: StoredWorkout.Source, device: StoredWorkout.Device? = nil) {
        self.uuid = uuid
        self.kind = kind
        self.startDate = startDate
        self.endDate = endDate
        self.value = value
        self.motionContext = motionContext
        self.source = source
        self.device = device
    }

    public init(_ sample: HKQuantitySample, kind: Kind) {
        let motion = (sample.metadata?[HKMetadataKeyHeartRateMotionContext] as? NSNumber).flatMap { HKHeartRateMotionContext(rawValue: $0.intValue) }
        self.init(
            uuid: sample.uuid,
            kind: kind,
            startDate: sample.startDate,
            endDate: sample.endDate,
            value: sample.quantity.doubleValue(for: kind.unit),
            motionContext: motion.flatMap {
                switch $0 {
                case .sedentary: .sedentary
                case .active: .active
                default: nil
                }
            },
            source: StoredWorkout.Source(sample.sourceRevision),
            device: sample.device.map(StoredWorkout.Device.init)
        )
    }
}
