//
//  Reservoir+CoreDataProperties.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/30/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Reservoir {

    @NSManaged var date: Date!
    @NSManaged var raw: Data?
    @NSManaged var primitiveVolume: NSNumber?
    @NSManaged var createdAt: Date!
    @NSManaged var pumpID: String!

}
