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
