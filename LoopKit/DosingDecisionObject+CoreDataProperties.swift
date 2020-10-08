//
//  DosingDecisionObject+CoreDataProperties.swift
//  LoopKit
//
//  Created by Darin Krauss on 5/4/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import CoreData

extension DosingDecisionObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DosingDecisionObject> {
        return NSFetchRequest<DosingDecisionObject>(entityName: "DosingDecisionObject")
    }

    @NSManaged public var data: Data
    @NSManaged public var date: Date
    @NSManaged public var modificationCounter: Int64
}
