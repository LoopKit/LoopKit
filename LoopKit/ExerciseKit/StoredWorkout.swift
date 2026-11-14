//
//  StoredWorkout.swift
//  LoopKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public struct StoredWorkout: Equatable, Sendable {
    public struct Source: Equatable, Sendable {
        public let bundleIdentifier: String
        public let name: String
        public let version: String?
        public let productType: String?
        public let operatingSystemVersion: String

        public init(bundleIdentifier: String, name: String, version: String? = nil, productType: String? = nil, operatingSystemVersion: String) {
            self.bundleIdentifier = bundleIdentifier
            self.name = name
            self.version = version
            self.productType = productType
            self.operatingSystemVersion = operatingSystemVersion
        }
    }

    public struct Device: Equatable, Sendable {
        public let name: String?
        public let model: String?
        public let manufacturer: String?
        public let hardwareVersion: String?
        public let firmwareVersion: String?
        public let softwareVersion: String?
        public let localIdentifier: String?
        public let udiDeviceIdentifier: String?

        public init(name: String? = nil, model: String? = nil, manufacturer: String? = nil, hardwareVersion: String? = nil, firmwareVersion: String? = nil, softwareVersion: String? = nil, localIdentifier: String? = nil, udiDeviceIdentifier: String? = nil) {
            self.name = name
            self.model = model
            self.manufacturer = manufacturer
            self.hardwareVersion = hardwareVersion
            self.firmwareVersion = firmwareVersion
            self.softwareVersion = softwareVersion
            self.localIdentifier = localIdentifier
            self.udiDeviceIdentifier = udiDeviceIdentifier
        }
    }

    public struct Event: Equatable, Sendable {
        public let type: HKWorkoutEventType
        public let startDate: Date
        public let duration: TimeInterval

        public init(type: HKWorkoutEventType, startDate: Date, duration: TimeInterval) {
            self.type = type
            self.startDate = startDate
            self.duration = duration
        }
    }

    public struct Activity: Equatable, Sendable {
        public let activityType: HKWorkoutActivityType
        public let startDate: Date
        public let endDate: Date?

        public init(activityType: HKWorkoutActivityType, startDate: Date, endDate: Date?) {
            self.activityType = activityType
            self.startDate = startDate
            self.endDate = endDate
        }
    }

    public enum MetadataValue: Equatable, Sendable {
        case string(String)
        case number(Double)
        case bool(Bool)
    }

    public let uuid: UUID
    public let startDate: Date
    public let endDate: Date
    public let duration: TimeInterval
    public let activityType: HKWorkoutActivityType
    public let totalEnergyBurned: Double?  // kcal
    public let totalDistance: Double?  // m
    public let averageHeartRate: Double?  // bpm
    public let minimumHeartRate: Double?
    public let maximumHeartRate: Double?
    public let source: Source
    public let device: Device?
    public let events: [Event]
    public let activities: [Activity]
    public let metadata: [String: MetadataValue]

    public init(uuid: UUID, startDate: Date, endDate: Date, duration: TimeInterval, activityType: HKWorkoutActivityType, totalEnergyBurned: Double? = nil, totalDistance: Double? = nil, averageHeartRate: Double? = nil, minimumHeartRate: Double? = nil, maximumHeartRate: Double? = nil, source: Source, device: Device? = nil, events: [Event] = [], activities: [Activity] = [], metadata: [String: MetadataValue] = [:]) {
        self.uuid = uuid
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.activityType = activityType
        self.totalEnergyBurned = totalEnergyBurned
        self.totalDistance = totalDistance
        self.averageHeartRate = averageHeartRate
        self.minimumHeartRate = minimumHeartRate
        self.maximumHeartRate = maximumHeartRate
        self.source = source
        self.device = device
        self.events = events
        self.activities = activities
        self.metadata = metadata
    }

    public var timeZone: TimeZone? {
        guard case .string(let identifier) = metadata[HKMetadataKeyTimeZone] else {
            return nil
        }
        return TimeZone(identifier: identifier)
    }
}

extension StoredWorkout {
    public init(_ workout: HKWorkout) {
        let heartRate = workout.statistics(for: HKQuantityType(.heartRate))
        let bpm = HKUnit.count().unitDivided(by: .minute())

        self.init(
            uuid: workout.uuid,
            startDate: workout.startDate,
            endDate: workout.endDate,
            duration: workout.duration,
            activityType: workout.workoutActivityType,
            totalEnergyBurned: workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()),
            totalDistance: workout.allStatistics.first { StoredWorkout.distanceTypes.contains($0.key) }?.value.sumQuantity()?.doubleValue(for: .meter()),
            averageHeartRate: heartRate?.averageQuantity()?.doubleValue(for: bpm),
            minimumHeartRate: heartRate?.minimumQuantity()?.doubleValue(for: bpm),
            maximumHeartRate: heartRate?.maximumQuantity()?.doubleValue(for: bpm),
            source: Source(workout.sourceRevision),
            device: workout.device.map(Device.init),
            events: (workout.workoutEvents ?? []).map {
                Event(type: $0.type, startDate: $0.dateInterval.start, duration: $0.dateInterval.duration)
            },
            activities: workout.workoutActivities.map {
                Activity(activityType: $0.workoutConfiguration.activityType, startDate: $0.startDate, endDate: $0.endDate)
            },
            metadata: (workout.metadata ?? [:]).compactMapValues(MetadataValue.init)
        )
    }
}

extension StoredWorkout.Source {
    init(_ revision: HKSourceRevision) {
        let os = revision.operatingSystemVersion
        self.init(
            bundleIdentifier: revision.source.bundleIdentifier,
            name: revision.source.name,
            version: revision.version,
            productType: revision.productType,
            operatingSystemVersion: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        )
    }
}

extension StoredWorkout.Device {
    init(_ device: HKDevice) {
        self.init(name: device.name, model: device.model, manufacturer: device.manufacturer, hardwareVersion: device.hardwareVersion, firmwareVersion: device.firmwareVersion, softwareVersion: device.softwareVersion, localIdentifier: device.localIdentifier, udiDeviceIdentifier: device.udiDeviceIdentifier)
    }
}

extension StoredWorkout {
    static let distanceTypes: Set<HKQuantityType> = [
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.distanceCycling),
        HKQuantityType(.distanceSwimming),
        HKQuantityType(.distanceWheelchair),
        HKQuantityType(.distanceDownhillSnowSports),
    ]
}

extension StoredWorkout.MetadataValue {
    init?(_ value: Any) {
        switch value {
        case let string as String:
            self = .string(string)
        case let date as Date:
            self = .string(date.ISO8601Format(Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
        case let quantity as HKQuantity:
            self = .string(String(describing: quantity))
        case let number as NSNumber:
            self = CFGetTypeID(number) == CFBooleanGetTypeID() ? .bool(number.boolValue) : .number(number.doubleValue)
        default:
            return nil
        }
    }
}
