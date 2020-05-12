//
//  DosingDecisionObject+CoreDataClass.swift
//  LoopKit
//
//  Created by Darin Krauss on 5/4/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import CoreData

class DosingDecisionObject: NSManagedObject {
    override func willSave() {
        if isInserted || isUpdated {
            setPrimitiveValue(managedObjectContext!.modificationCounter ?? 0, forKey: "modificationCounter")
        }
        super.willSave()
    }
}
