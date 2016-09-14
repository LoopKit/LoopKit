//
//  PumpEvent+CoreDataProperties.swift
//  LoopKit
//
//  Created by Nate Racklyeft on 8/1/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension PumpEvent {

    @NSManaged var createdAt: Date!
    @NSManaged var date: Date!
    @NSManaged var primitiveDuration: NSNumber?
    @NSManaged var primitiveType: String?
    @NSManaged var primitiveUnit: String?
    @NSManaged var primitiveUploaded: NSNumber?
    @NSManaged var primitiveValue: NSNumber?
    @NSManaged var pumpID: String?
    @NSManaged var raw: Data?
    @NSManaged var title: String?

}
