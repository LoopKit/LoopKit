//
//  CachedGlucoseObject+CoreDataProperties.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//
//

import Foundation
import CoreData
import HealthKit


extension CachedGlucoseObject {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CachedGlucoseObject> {
        return NSFetchRequest<CachedGlucoseObject>(entityName: "CachedGlucoseObject")
    }

    /// This is the UUID provided from HealthKit.  Nil if not (yet) stored in HealthKit.  Note: it is _not_ a unique identifier for this object.
    @NSManaged public var uuid: UUID?
    @NSManaged public var provenanceIdentifier: String
    @NSManaged public var syncIdentifier: String?
    @NSManaged public var primitiveSyncVersion: NSNumber?
    @NSManaged public var value: Double
    @NSManaged public var unitString: String
    @NSManaged public var startDate: Date
    @NSManaged public var isDisplayOnly: Bool
    @NSManaged public var wasUserEntered: Bool
    @NSManaged public var modificationCounter: Int64
    @NSManaged public var primitiveDevice: Data?
    @NSManaged public var primitiveCondition: String?
    @NSManaged public var primitiveTrend: NSNumber?
    @NSManaged public var trendRateUnit: String?
    @NSManaged public var trendRateValue: NSNumber?
    /// This is the date when this object is eligible for writing to HealthKit.  For example, if it is required to delay writing
    /// data to HealthKit, this date will be in the future.  If the date is in the past, then it is written to HealthKit as soon as possible,
    /// and this value is set to `nil`.  A `nil` value either means that this object has already been written to HealthKit, or it is
    /// not eligible for HealthKit in the first place (for example, if a user has denied permissions at the time the sample was taken).
    @NSManaged public var healthKitEligibleDate: Date?
}

extension CachedGlucoseObject: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(uuid, forKey: .uuid)
        try container.encode(provenanceIdentifier, forKey: .provenanceIdentifier)
        try container.encodeIfPresent(syncIdentifier, forKey: .syncIdentifier)
        try container.encodeIfPresent(syncVersion, forKey: .syncVersion)
        try container.encode(value, forKey: .value)
        try container.encode(unitString, forKey: .unitString)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(isDisplayOnly, forKey: .isDisplayOnly)
        try container.encode(wasUserEntered, forKey: .wasUserEntered)
        try container.encode(modificationCounter, forKey: .modificationCounter)
        try container.encodeIfPresent(device, forKey: .device)
        try container.encodeIfPresent(condition, forKey: .condition)
        try container.encodeIfPresent(trend, forKey: .trend)
        try container.encodeIfPresent(trendRateUnit, forKey: .trendRateUnit)
        try container.encodeIfPresent(trendRateValue?.doubleValue, forKey: .trendRateValue)
        try container.encodeIfPresent(healthKitEligibleDate, forKey: .healthKitEligibleDate)
    }

    private enum CodingKeys: String, CodingKey {
        case uuid
        case provenanceIdentifier
        case syncIdentifier
        case syncVersion
        case value
        case unitString
        case startDate
        case isDisplayOnly
        case wasUserEntered
        case modificationCounter
        case device
        case condition
        case trend
        case trendRateUnit
        case trendRateValue
        case healthKitEligibleDate
    }
}

extension GlucoseTrend: Codable {}
