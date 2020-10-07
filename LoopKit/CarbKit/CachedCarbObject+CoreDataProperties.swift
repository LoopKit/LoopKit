//
//  CachedCarbObject+CoreDataProperties.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//
//

import Foundation
import CoreData


extension CachedCarbObject {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CachedCarbObject> {
        return NSFetchRequest<CachedCarbObject>(entityName: "CachedCarbObject")
    }

    @NSManaged public var primitiveAbsorptionTime: NSNumber?
    @NSManaged public var createdByCurrentApp: Bool
    @NSManaged public var foodType: String?
    @NSManaged public var grams: Double
    @NSManaged public var startDate: Date
    @NSManaged public var uuid: UUID?
    @NSManaged public var provenanceIdentifier: String?
    @NSManaged public var syncIdentifier: String?
    @NSManaged public var primitiveSyncVersion: NSNumber?
    @NSManaged public var userCreatedDate: Date?
    @NSManaged public var userUpdatedDate: Date?
    @NSManaged public var userDeletedDate: Date?
    @NSManaged public var primitiveOperation: NSNumber
    @NSManaged public var addedDate: Date?
    @NSManaged public var supercededDate: Date?
    @NSManaged public var anchorKey: Int64

}

extension CachedCarbObject: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(absorptionTime, forKey: .absorptionTime)
        try container.encode(createdByCurrentApp, forKey: .createdByCurrentApp)
        try container.encodeIfPresent(foodType, forKey: .foodType)
        try container.encode(grams, forKey: .grams)
        try container.encode(startDate, forKey: .startDate)
        try container.encodeIfPresent(uuid, forKey: .uuid)
        try container.encodeIfPresent(provenanceIdentifier, forKey: .provenanceIdentifier)
        try container.encodeIfPresent(syncIdentifier, forKey: .syncIdentifier)
        try container.encodeIfPresent(syncVersion, forKey: .syncVersion)
        try container.encodeIfPresent(userCreatedDate, forKey: .userCreatedDate)
        try container.encodeIfPresent(userUpdatedDate, forKey: .userUpdatedDate)
        try container.encodeIfPresent(userDeletedDate, forKey: .userDeletedDate)
        try container.encodeIfPresent(operation, forKey: .operation)
        try container.encodeIfPresent(addedDate, forKey: .addedDate)
        try container.encodeIfPresent(supercededDate, forKey: .supercededDate)
        try container.encode(anchorKey, forKey: .anchorKey)
    }

    private enum CodingKeys: String, CodingKey {
        case absorptionTime
        case createdByCurrentApp
        case foodType
        case grams
        case startDate
        case uuid
        case provenanceIdentifier
        case syncIdentifier
        case syncVersion
        case userCreatedDate
        case userUpdatedDate
        case userDeletedDate
        case operation
        case addedDate
        case supercededDate
        case anchorKey
    }
}
