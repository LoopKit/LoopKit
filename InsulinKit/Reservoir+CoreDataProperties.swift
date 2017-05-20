//
//  Reservoir+CoreDataProperties.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 1/30/16.
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import Foundation
import CoreData


extension Reservoir {

    @nonobjc class func fetchRequest() -> NSFetchRequest<Reservoir> {
        return NSFetchRequest<Reservoir>(entityName: "Reservoir")
    }

    @NSManaged var createdAt: Date!
    @NSManaged var date: Date!
    @NSManaged var primitiveVolume: NSNumber?
    @NSManaged var raw: Data?

}
