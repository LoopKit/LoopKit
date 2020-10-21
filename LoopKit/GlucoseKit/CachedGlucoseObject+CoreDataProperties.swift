//
//  CachedGlucoseObject+CoreDataProperties.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//
//

import Foundation
import CoreData


extension CachedGlucoseObject {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CachedGlucoseObject> {
        return NSFetchRequest<CachedGlucoseObject>(entityName: "CachedGlucoseObject")
    }

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
    }
}
