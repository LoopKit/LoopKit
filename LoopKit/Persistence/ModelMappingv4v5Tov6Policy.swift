//
//  ModelMappingv4v5Tov6Policy.swift
//  LoopKit
//
//  Created by Cameron Ingham on 7/29/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import Foundation
import CoreData

class DosingDecisionObjectMigrationPolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(
        forSource sInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        print("🟢 Custom migration policy is running!")
        try super.createDestinationInstances(
            forSource: sInstance,
            in: mapping,
            manager: manager
        )

        guard let destInstance = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [sInstance]
        ).first else {
            return
        }

        // Decode the ID from data
        if let data = sInstance.value(forKey: "data") as? Data {
            let decoder = PropertyListDecoder()
            struct Payload: Decodable { let id: UUID }

            print("data exists \(data)")
            
            if let payload = try? decoder.decode(Payload.self, from: data) {
                print("payload exists \(payload)")
                destInstance.setValue(payload.id, forKey: "id")
                
                assert(destInstance.value(forKey: "id") as? UUID == payload.id)
            }
        }
    }
}
