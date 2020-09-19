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
    @NSManaged public var syncIdentifier: String?
    @NSManaged public var syncVersion: Int32
    @NSManaged public var primitiveUploadState: NSNumber?
    @NSManaged public var value: Double
    @NSManaged public var unitString: String?
    @NSManaged public var primitiveStartDate: NSDate?
    @NSManaged public var provenanceIdentifier: String?
    @NSManaged public var isDisplayOnly: Bool
    @NSManaged public var wasUserEntered: Bool
    @NSManaged public var modificationCounter: Int64

}

extension CachedGlucoseObject: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(uuid, forKey: .uuid)
        try container.encodeIfPresent(syncIdentifier, forKey: .syncIdentifier)
        try container.encode(syncVersion, forKey: .syncVersion)
        try container.encode(uploadState.rawValue, forKey: .uploadState)
        try container.encode(value, forKey: .value)
        try container.encodeIfPresent(unitString, forKey: .unitString)
        try container.encode(startDate, forKey: .startDate)
        try container.encodeIfPresent(provenanceIdentifier, forKey: .provenanceIdentifier)
        try container.encode(isDisplayOnly, forKey: .isDisplayOnly)
        try container.encode(wasUserEntered, forKey: .wasUserEntered)
        try container.encode(modificationCounter, forKey: .modificationCounter)
    }

    private enum CodingKeys: String, CodingKey {
        case uuid
        case syncIdentifier
        case syncVersion
        case uploadState
        case value
        case unitString
        case startDate
        case provenanceIdentifier
        case isDisplayOnly
        case wasUserEntered
        case modificationCounter
    }
}
