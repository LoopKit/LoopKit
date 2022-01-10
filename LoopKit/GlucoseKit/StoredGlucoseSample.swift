//
//  StoredGlucoseSample.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import HealthKit

public struct StoredGlucoseSample: GlucoseSampleValue, Equatable {
    public let uuid: UUID?  // Note this is the UUID from HealthKit.  Nil if not (yet) stored in HealthKit.

    // MARK: - HealthKit Sync Support

    public let provenanceIdentifier: String
    public let syncIdentifier: String?
    public let syncVersion: Int?
    public let device: HKDevice?
    public let healthKitEligibleDate: Date?

    // MARK: - SampleValue

    public let startDate: Date
    public let quantity: HKQuantity

    // MARK: - GlucoseSampleValue

    public let isDisplayOnly: Bool
    public let wasUserEntered: Bool
    public let condition: GlucoseCondition?
    public let trend: GlucoseTrend?
    public let trendRate: HKQuantity?

    public init(sample: HKQuantitySample) {
        self.init(
            uuid: sample.uuid,
            provenanceIdentifier: sample.provenanceIdentifier,
            syncIdentifier: sample.syncIdentifier,
            syncVersion: sample.syncVersion,
            startDate: sample.startDate,
            quantity: sample.quantity,
            condition: sample.condition,
            trend: sample.trend,
            trendRate: sample.trendRate,
            isDisplayOnly: sample.isDisplayOnly,
            wasUserEntered: sample.wasUserEntered,
            device: sample.device,
            healthKitEligibleDate: nil)
    }

    public init(
        uuid: UUID?,
        provenanceIdentifier: String,
        syncIdentifier: String?,
        syncVersion: Int?,
        startDate: Date,
        quantity: HKQuantity,
        condition: GlucoseCondition?,
        trend: GlucoseTrend?,
        trendRate: HKQuantity?,
        isDisplayOnly: Bool,
        wasUserEntered: Bool,
        device: HKDevice?,
        healthKitEligibleDate: Date?) {
        self.uuid = uuid
        self.provenanceIdentifier = provenanceIdentifier
        self.syncIdentifier = syncIdentifier
        self.syncVersion = syncVersion
        self.startDate = startDate
        self.quantity = quantity
        self.condition = condition
        self.trend = trend
        self.trendRate = trendRate
        self.isDisplayOnly = isDisplayOnly
        self.wasUserEntered = wasUserEntered
        self.device = device
        self.healthKitEligibleDate = healthKitEligibleDate
    }
}

extension StoredGlucoseSample {
    init(managedObject: CachedGlucoseObject) {
        self.init(
            uuid: managedObject.uuid,
            provenanceIdentifier: managedObject.provenanceIdentifier,
            syncIdentifier: managedObject.syncIdentifier,
            syncVersion: managedObject.syncVersion,
            startDate: managedObject.startDate,
            quantity: managedObject.quantity,
            condition: managedObject.condition,
            trend: managedObject.trend,
            trendRate: managedObject.trendRate,
            isDisplayOnly: managedObject.isDisplayOnly,
            wasUserEntered: managedObject.wasUserEntered,
            device: managedObject.device,
            healthKitEligibleDate: managedObject.healthKitEligibleDate)
    }
}

extension StoredGlucoseSample: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(uuid: try container.decodeIfPresent(UUID.self, forKey: .uuid),
                  provenanceIdentifier: try container.decode(String.self, forKey: .provenanceIdentifier),
                  syncIdentifier: try container.decodeIfPresent(String.self, forKey: .syncIdentifier),
                  syncVersion: try container.decodeIfPresent(Int.self, forKey: .syncVersion),
                  startDate: try container.decode(Date.self, forKey: .startDate),
                  quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: try container.decode(Double.self, forKey: .quantity)),
                  condition: try container.decodeIfPresent(GlucoseCondition.self, forKey: .condition),
                  trend: try container.decodeIfPresent(GlucoseTrend.self, forKey: .trend),
                  trendRate: try container.decodeIfPresent(Double.self, forKey: .trendRate).map { HKQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: $0) },
                  isDisplayOnly: try container.decode(Bool.self, forKey: .isDisplayOnly),
                  wasUserEntered: try container.decode(Bool.self, forKey: .wasUserEntered),
                  device: try container.decodeIfPresent(CodableDevice.self, forKey: .device).map { $0.device },
                  healthKitEligibleDate: try container.decodeIfPresent(Date.self, forKey: .healthKitEligibleDate))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(uuid, forKey: .uuid)
        try container.encode(provenanceIdentifier, forKey: .provenanceIdentifier)
        try container.encodeIfPresent(syncIdentifier, forKey: .syncIdentifier)
        try container.encodeIfPresent(syncVersion, forKey: .syncVersion)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(quantity.doubleValue(for: .milligramsPerDeciliter), forKey: .quantity)
        try container.encodeIfPresent(condition, forKey: .condition)
        try container.encodeIfPresent(trend, forKey: .trend)
        try container.encodeIfPresent(trendRate?.doubleValue(for: .milligramsPerDeciliterPerMinute), forKey: .trendRate)
        try container.encode(isDisplayOnly, forKey: .isDisplayOnly)
        try container.encode(wasUserEntered, forKey: .wasUserEntered)
        try container.encodeIfPresent(device.map { CodableDevice($0) }, forKey: .device)
        try container.encodeIfPresent(healthKitEligibleDate, forKey: .healthKitEligibleDate)
    }

    private enum CodingKeys: String, CodingKey {
        case uuid
        case provenanceIdentifier
        case syncIdentifier
        case syncVersion
        case startDate
        case quantity
        case condition
        case trend
        case trendRate
        case isDisplayOnly
        case wasUserEntered
        case device
        case healthKitEligibleDate
    }
}
