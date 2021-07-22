//
//  CachedInsulinDeliveryObject+CoreDataProperties.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//
//

import Foundation
import CoreData


extension CachedInsulinDeliveryObject {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CachedInsulinDeliveryObject> {
        return NSFetchRequest<CachedInsulinDeliveryObject>(entityName: "CachedInsulinDeliveryObject")
    }

    @NSManaged public var uuid: UUID?
    @NSManaged public var provenanceIdentifier: String
    @NSManaged public var hasLoopKitOrigin: Bool
    @NSManaged public var startDate: Date
    @NSManaged public var endDate: Date
    @NSManaged public var syncIdentifier: String?
    @NSManaged public var value: Double
    @NSManaged public var primitiveScheduledBasalRate: NSNumber?
    @NSManaged public var primitiveProgrammedTempBasalRate: NSNumber?
    @NSManaged public var primitiveReason: NSNumber?
    @NSManaged public var createdAt: Date?
    @NSManaged public var primitiveInsulinType: NSNumber?
    @NSManaged public var primitiveAutomaticallyIssued: NSNumber?
}
