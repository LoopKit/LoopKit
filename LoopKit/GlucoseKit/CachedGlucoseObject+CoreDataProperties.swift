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
    @NSManaged public var modificationCounter: Int64

}
