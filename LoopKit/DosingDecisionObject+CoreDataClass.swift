//
//  DosingDecisionObject+CoreDataClass.swift
//  LoopKit
//
//  Created by Darin Krauss on 5/4/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import CoreData

class DosingDecisionObject: NSManagedObject {
    var hasUpdatedModificationCounter: Bool { changedValues().keys.contains("modificationCounter") }

    func updateModificationCounter() { setPrimitiveValue(managedObjectContext!.modificationCounter!, forKey: "modificationCounter") }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        updateID()
        updateModificationCounter()
    }
    
    override func awakeFromFetch() {
        super.awakeFromFetch()
        updateID()
    }
    
    public override func willSave() {
        if isUpdated && !hasUpdatedModificationCounter {
            updateModificationCounter()
        }
        super.willSave()
    }

    private struct RawDosingDecision: Decodable {
        let id: UUID
    }
    
    private func updateID() {
        self.id = try! PropertyListDecoder().decode(RawDosingDecision.self, from: data).id
    }
}
