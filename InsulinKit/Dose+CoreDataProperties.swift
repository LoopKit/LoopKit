//
//  Dose+CoreDataProperties.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 3/28/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Dose {

    @NSManaged var createdAt: NSDate!
    @NSManaged var date: NSDate!
    @NSManaged var primitiveDuration: NSNumber?
    @NSManaged var primitiveUnit: String?
    @NSManaged var primitiveType: String?
    @NSManaged var pumpID: String?
    @NSManaged var raw: NSData?

}
