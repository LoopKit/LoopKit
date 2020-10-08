//
//  SettingsObject+CoreDataClass.swift
//  LoopKit
//
//  Created by Darin Krauss on 4/30/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import CoreData

class SettingsObject: NSManagedObject {
    var hasUpdatedModificationCounter: Bool { changedValues().keys.contains("modificationCounter") }

    func updateModificationCounter() { setPrimitiveValue(managedObjectContext!.modificationCounter!, forKey: "modificationCounter") }

    override func awakeFromInsert() {
        super.awakeFromInsert()
        updateModificationCounter()
    }

    override func willSave() {
        if isUpdated && !hasUpdatedModificationCounter {
            updateModificationCounter()
        }
        super.willSave()
    }
}
