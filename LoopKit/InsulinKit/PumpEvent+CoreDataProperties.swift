//
//  PumpEvent+CoreDataProperties.swift
//  LoopKit
//
//  Created by Nate Racklyeft on 8/1/16.
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import Foundation
import CoreData


extension PumpEvent {

    @nonobjc class func fetchRequest() -> NSFetchRequest<PumpEvent> {
        return NSFetchRequest<PumpEvent>(entityName: "PumpEvent")
    }

    @NSManaged var createdAt: Date!
    @NSManaged var date: Date!
    @NSManaged var primitiveDoseType: String?
    @NSManaged var primitiveDuration: NSNumber?
    @NSManaged var primitiveType: String?
    @NSManaged var primitiveUnit: String?
    @NSManaged var primitiveUploaded: NSNumber?
    @NSManaged var primitiveValue: NSNumber?
    @NSManaged var primitiveDeliveredUnits: NSNumber?
    @NSManaged var mutable: Bool
    @NSManaged var raw: Data?
    @NSManaged var title: String?
    @NSManaged var modificationCounter: Int64

}
