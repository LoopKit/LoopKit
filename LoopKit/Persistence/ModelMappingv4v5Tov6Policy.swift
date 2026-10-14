//
//  ModelMappingv4v5Tov6Policy.swift
//  LoopKit
//
//  Created by Cameron Ingham on 7/29/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import Foundation
import CoreData
import HealthKit

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

        // Decode the ID from data
        if let destInstance = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [sInstance]
        ).first, let data = sInstance.value(forKey: "data") as? Data {
            let decoder = PropertyListDecoder()
            struct Payload: Decodable { let id: UUID }

            if let payload = try? decoder.decode(Payload.self, from: data) {
                destInstance.setValue(payload.id, forKey: "id")
                assert(destInstance.value(forKey: "id") as? UUID == payload.id)
            }
        }
    }
}

/// Modelv4 stored a dose's delivered insulin amount in a single `value` attribute.
/// Modelv6 replaced that with `deliveredUnits` (and `programmedUnits` for boluses).
/// Without this policy the v4→v6 mapping would drop `value` (auto-generated, name-based
/// mappings have no `value` destination), leaving boluses with no units — understating IOB
/// and tripping a read-time assertion. Carry the amount forward so upgrades preserve insulin
/// history. (`value` was always delivered units; the basal *rate* lives in the separate
/// scheduledBasalRate/programmedTempBasalRate attributes, which migrate by name.)
class CachedInsulinDeliveryObjectMigrationPolicy: NSEntityMigrationPolicy {
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
        ).first,
        let value = (sInstance.value(forKey: "value") as? NSNumber)?.doubleValue else {
            return
        }

        destInstance.setValue(value, forKey: "deliveredUnits")

        if (sInstance.value(forKey: "reason") as? NSNumber)?.intValue == HKInsulinDeliveryReason.bolus.rawValue {
            destInstance.setValue(value, forKey: "programmedUnits")
        }
    }
}
