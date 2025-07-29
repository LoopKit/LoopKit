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
        
        if let jsonData = sInstance.value(forKey: "data") as? Data {
            let decoder = JSONDecoder()
            struct Payload: Decodable { let id: UUID }
            
            if let payload = try? decoder.decode(
                Payload.self,
                from: jsonData
            ) {
                destInstance.setValue(payload.id, forKey: "id")
            }
        }
    }
}
