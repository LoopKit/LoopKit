//
//  Modelv3EntityMigrationPolicy.swift
//  LoopKit
//
//  Created by Darin Krauss on 8/24/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import CoreData
import HealthKit

class CachedCarbObjectv3EntityMigrationPolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(forSource sourceInstance: NSManagedObject, in mapping: NSEntityMapping, manager: NSMigrationManager) throws {

        // Perform lightweight migration
        try super.createDestinationInstances(forSource: sourceInstance, in: mapping, manager: manager)

        // Find assigned destination instance based upon previous lightweight migration
        let destinationInstance = manager.destinationInstances(forEntityMappingName: mapping.name, sourceInstances: [sourceInstance]).first!

        // Only for Loop-specific data
        if destinationInstance.createdByCurrentApp {

            // Since this is known Loop data, migrate to use correct provenance identifier
            destinationInstance.provenanceIdentifier = HKSource.default().bundleIdentifier

            // Since this is known Loop data, migrate any known update operations when sync version > 1
            // Note: Default operation upon migration (according to data model) is create
            if destinationInstance.syncIdentifier != nil, let syncVersion = destinationInstance.syncVersion, syncVersion > 1 {
                destinationInstance.operation = .update
            }
        }

        // If any external ID and no sync identifier, then use that with initial version
        if let externalID = sourceInstance.externalID, destinationInstance.syncIdentifier == nil {
            destinationInstance.syncIdentifier = externalID
            destinationInstance.syncVersion = 1
        }
    }
}

class DeletedCarbObjectv3EntityMigrationPolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(forSource sourceInstance: NSManagedObject, in mapping: NSEntityMapping, manager: NSMigrationManager) throws {

        // Create new destination instance from scratch since the source entity is being deleted
        let destinationInstance = NSEntityDescription.insertNewObject(forEntityName: mapping.destinationEntityName!, into: manager.destinationContext)

        // Migrate from DeletedCarbObject to CachedCarbObject
        destinationInstance.createdByCurrentApp = false                     // Since we don't know from DeletedCarbObject, it is safest to assume not
        destinationInstance.startDate = sourceInstance.startDate
        destinationInstance.uuid = sourceInstance.uuid
        destinationInstance.syncIdentifier = sourceInstance.syncIdentifier
        destinationInstance.syncVersion = sourceInstance.syncVersion
        destinationInstance.operation = .delete
        destinationInstance.anchorKey = sourceInstance.modificationCounter  // Manually retain modification counter in anchor key

        // If any external ID and no sync identifier, then use that with initial version
        if let externalID = sourceInstance.externalID, sourceInstance.syncIdentifier == nil {
            destinationInstance.syncIdentifier = externalID
            destinationInstance.syncVersion = 1
        }

        // Associate new destination instance with the previous source instance
        manager.associate(sourceInstance: sourceInstance, withDestinationInstance: destinationInstance, for: mapping)
    }
}

fileprivate extension NSManagedObject {
    var createdByCurrentApp: Bool {
        get { value(forKey: "createdByCurrentApp") as! Bool == true }
        set { setValue(newValue, forKey: "createdByCurrentApp") }
    }

    var startDate: Date {
        get { value(forKey: "startDate") as! Date }
        set { setValue(newValue, forKey: "startDate") }
    }

    var uuid: UUID? {
        get { value(forKey: "uuid") as? UUID }
        set { setValue(newValue, forKey: "uuid") }
    }

    var provenanceIdentifier: String? {
        get { value(forKey: "provenanceIdentifier") as? String }
        set { setValue(newValue, forKey: "provenanceIdentifier") }
    }

    var syncIdentifier: String? {
        get { value(forKey: "syncIdentifier") as? String }
        set { setValue(newValue, forKey: "syncIdentifier") }
    }

    var syncVersion: Int? {
        get { (value(forKey: "syncVersion") as? Int32).map { Int($0) } }
        set { setValue(newValue.map { Int32($0) }, forKey: "syncVersion") }
    }

    var operation: Operation {
        get { Operation(rawValue: Int(value(forKey: "operation") as! Int32))! }
        set { setValue(Int32(newValue.rawValue), forKey: "operation") }
    }

    var anchorKey: Int64 {
        get { value(forKey: "anchorKey") as! Int64 }
        set { setValue(newValue, forKey: "anchorKey") }
    }

    var externalID: String? { value(forKey: "externalID") as? String }

    var modificationCounter: Int64 { value(forKey: "modificationCounter") as! Int64 }
}
