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
    @NSManaged public var externalID: String?
    @NSManaged public var foodType: String?
    @NSManaged public var grams: Double
    @NSManaged public var primitiveStartDate: NSDate?
    @NSManaged public var uuid: UUID?
    @NSManaged public var syncIdentifier: String?
    @NSManaged public var syncVersion: Int32
    @NSManaged public var modificationCounter: Int64

}
