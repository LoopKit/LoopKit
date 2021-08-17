//
//  CachedInsulinDeliveryObjectTests.swift
//  LoopKitTests
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
@testable import LoopKit

class CachedInsulinDeliveryObjectTests: PersistenceControllerTestCase {
    func testReasonGet() {
        cacheStore.managedObjectContext.performAndWait {
            let object = CachedInsulinDeliveryObject(context: cacheStore.managedObjectContext)
            object.primitiveReason = NSNumber(integerLiteral: 2)
            XCTAssertEqual(object.reason, .bolus)
        }
    }

    func testReasonSet() {
        cacheStore.managedObjectContext.performAndWait {
            let object = CachedInsulinDeliveryObject(context: cacheStore.managedObjectContext)
            object.reason = .basal
            XCTAssertEqual(object.primitiveReason, NSNumber(integerLiteral: 1))
        }
    }

    func testScheduledBasalRateGet() {
        cacheStore.managedObjectContext.performAndWait {
            let object = CachedInsulinDeliveryObject(context: cacheStore.managedObjectContext)
            object.primitiveScheduledBasalRate = NSNumber(floatLiteral: 1.23)
            XCTAssertEqual(object.scheduledBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 1.23))
        }
    }

    func testScheduledBasalRateGetNil() {
        cacheStore.managedObjectContext.performAndWait {
            let object = CachedInsulinDeliveryObject(context: cacheStore.managedObjectContext)
            object.primitiveScheduledBasalRate = nil
            XCTAssertNil(object.scheduledBasalRate)
        }
    }

    func testScheduledBasalRateSet() {
        cacheStore.managedObjectContext.performAndWait {
            let object = CachedInsulinDeliveryObject(context: cacheStore.managedObjectContext)
            object.scheduledBasalRate = HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 2.34)
            XCTAssertEqual(object.primitiveScheduledBasalRate, NSNumber(floatLiteral: 2.34))
        }
    }

    func testScheduledBasalRateSetNil() {
        cacheStore.managedObjectContext.performAndWait {
            let object = CachedInsulinDeliveryObject(context: cacheStore.managedObjectContext)
            object.scheduledBasalRate = nil
            XCTAssertNil(object.primitiveScheduledBasalRate)
        }
    }

    func testPrimitiveProgrammedTempBasalRateGet() {
        cacheStore.managedObjectContext.performAndWait {
            let object = CachedInsulinDeliveryObject(context: cacheStore.managedObjectContext)
            object.primitiveProgrammedTempBasalRate = NSNumber(floatLiteral: 1.23)
            XCTAssertEqual(object.programmedTempBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 1.23))
        }
    }

    func testPrimitiveProgrammedTempBasalRateGetNil() {
        cacheStore.managedObjectContext.performAndWait {
            let object = CachedInsulinDeliveryObject(context: cacheStore.managedObjectContext)
            object.primitiveProgrammedTempBasalRate = nil
            XCTAssertNil(object.programmedTempBasalRate)
        }
    }

    func testPrimitiveProgrammedTempBasalRateSet() {
        cacheStore.managedObjectContext.performAndWait {
            let object = CachedInsulinDeliveryObject(context: cacheStore.managedObjectContext)
            object.programmedTempBasalRate = HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 2.34)
            XCTAssertEqual(object.primitiveProgrammedTempBasalRate, NSNumber(floatLiteral: 2.34))
        }
    }

    func testPrimitiveProgrammedTempBasalRateSetNil() {
        cacheStore.managedObjectContext.performAndWait {
            let object = CachedInsulinDeliveryObject(context: cacheStore.managedObjectContext)
            object.programmedTempBasalRate = nil
            XCTAssertNil(object.primitiveProgrammedTempBasalRate)
        }
    }
}

class CachedInsulinDeliveryObjectDoseTests: PersistenceControllerTestCase {
    func testDoseBasal() {
        cacheStore.managedObjectContext.performAndWait {
            let object = CachedInsulinDeliveryObject(context: cacheStore.managedObjectContext)
            object.provenanceIdentifier = Bundle.main.bundleIdentifier!
            object.hasLoopKitOrigin = true
            object.startDate = dateFormatter.date(from: "2020-01-02T03:04:05Z")!
            object.endDate = dateFormatter.date(from: "2020-01-02T04:04:05Z")!
            object.syncIdentifier = "876DDBF9-CC47-45ED-B0D7-AD77B77913C4"
            object.value = 0.5
            object.scheduledBasalRate = nil
            object.programmedTempBasalRate = nil
            object.reason = .basal
            object.createdAt = dateFormatter.date(from: "2020-01-02T04:04:06Z")!
            let dose = object.dose
            XCTAssertNotNil(dose)
            XCTAssertEqual(dose!.type, .basal)
            XCTAssertEqual(dose!.startDate, dateFormatter.date(from: "2020-01-02T03:04:05Z")!)
            XCTAssertEqual(dose!.endDate, dateFormatter.date(from: "2020-01-02T04:04:05Z")!)
            XCTAssertEqual(dose!.value, 0.5)
            XCTAssertEqual(dose!.unit, .units)
            XCTAssertEqual(dose!.deliveredUnits, nil)
            XCTAssertEqual(dose!.description, nil)
            XCTAssertEqual(dose!.syncIdentifier, "876DDBF9-CC47-45ED-B0D7-AD77B77913C4")
            XCTAssertEqual(dose!.scheduledBasalRate, nil)
        }
    }

    func testDoseTempBasal() {
        cacheStore.managedObjectContext.performAndWait {
            let object = CachedInsulinDeliveryObject(context: cacheStore.managedObjectContext)
            object.provenanceIdentifier = Bundle.main.bundleIdentifier!
            object.hasLoopKitOrigin = false
            object.startDate = dateFormatter.date(from: "2020-01-02T03:04:06Z")!
            object.endDate = dateFormatter.date(from: "2020-01-02T03:34:06Z")!
            object.syncIdentifier = nil
            object.value = 0.75
            object.scheduledBasalRate = HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 1.0)
            object.programmedTempBasalRate = HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 1.5)
            object.reason = .basal
            object.createdAt = dateFormatter.date(from: "2020-01-02T04:04:07Z")!
            let dose = object.dose
            XCTAssertNotNil(dose)
            XCTAssertEqual(dose!.type, .tempBasal)
            XCTAssertEqual(dose!.startDate, dateFormatter.date(from: "2020-01-02T03:04:06Z")!)
            XCTAssertEqual(dose!.endDate, dateFormatter.date(from: "2020-01-02T03:34:06Z")!)
            XCTAssertEqual(dose!.value, 1.5)
            XCTAssertEqual(dose!.unit, .unitsPerHour)
            XCTAssertEqual(dose!.deliveredUnits, 0.75)
            XCTAssertEqual(dose!.description, nil)
            XCTAssertEqual(dose!.syncIdentifier, nil)
            XCTAssertEqual(dose!.scheduledBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 1.0))
        }
    }

    func testDoseBolus() {
        cacheStore.managedObjectContext.performAndWait {
            let object = CachedInsulinDeliveryObject(context: cacheStore.managedObjectContext)
            object.provenanceIdentifier = Bundle.main.bundleIdentifier!
            object.hasLoopKitOrigin = true
            object.startDate = dateFormatter.date(from: "2020-01-02T05:04:05Z")!
            object.endDate = dateFormatter.date(from: "2020-01-02T05:05:05Z")!
            object.syncIdentifier = "9AA61454-EED5-476F-8E57-4BA63D0267C1"
            object.value = 2.25
            object.scheduledBasalRate = nil
            object.programmedTempBasalRate = nil
            object.reason = .bolus
            object.createdAt = dateFormatter.date(from: "2020-01-02T05:05:06Z")!
            let dose = object.dose
            XCTAssertNotNil(dose)
            XCTAssertEqual(dose!.type, .bolus)
            XCTAssertEqual(dose!.startDate, dateFormatter.date(from: "2020-01-02T05:04:05Z")!)
            XCTAssertEqual(dose!.endDate, dateFormatter.date(from: "2020-01-02T05:05:05Z")!)
            XCTAssertEqual(dose!.value, 2.25)
            XCTAssertEqual(dose!.unit, .units)
            XCTAssertEqual(dose!.deliveredUnits, nil)
            XCTAssertEqual(dose!.description, nil)
            XCTAssertEqual(dose!.syncIdentifier, "9AA61454-EED5-476F-8E57-4BA63D0267C1")
            XCTAssertEqual(dose!.scheduledBasalRate, nil)
        }
    }

    private let dateFormatter = ISO8601DateFormatter()
}

class CachedInsulinDeliveryObjectOperationsTests: PersistenceControllerTestCase {
    func testCreateWithoutUUID() {
        let metadata: [String: Any] = [
            HKMetadataKeySyncIdentifier: "AF41499D-973E-4974-AE03-D57083F5353C",
            HKMetadataKeySyncVersion: 2,
            HKMetadataKeyInsulinDeliveryReason: HKInsulinDeliveryReason.basal.rawValue,
            MetadataKeyHasLoopKitOrigin: true,
            MetadataKeyScheduledBasalRate: HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 1.0),
            MetadataKeyProgrammedTempBasalRate: HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 1.5)
            
        ]
        let sample = HKQuantitySample(type: HKQuantityType.quantityType(forIdentifier: .insulinDelivery)!,
                                      quantity: HKQuantity(unit: .internationalUnit(), doubleValue: 0.75),
                                      start: dateFormatter.date(from: "2020-01-02T03:04:05Z")!,
                                      end: dateFormatter.date(from: "2020-01-02T03:34:05Z")!,
                                      metadata: metadata)
        cacheStore.managedObjectContext.performAndWait {
            let object = CachedInsulinDeliveryObject(context: cacheStore.managedObjectContext)
            object.create(fromNew: sample, on: dateFormatter.date(from: "2020-01-02T03:34:06Z")!)
            XCTAssertNil(object.uuid)
            XCTAssertEqual(object.hasLoopKitOrigin, true)
            XCTAssertEqual(object.startDate, dateFormatter.date(from: "2020-01-02T03:04:05Z")!)
            XCTAssertEqual(object.endDate, dateFormatter.date(from: "2020-01-02T03:34:05Z")!)
            XCTAssertEqual(object.syncIdentifier, "AF41499D-973E-4974-AE03-D57083F5353C")
            XCTAssertEqual(object.value, 0.75)
            XCTAssertEqual(object.scheduledBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 1.0))
            XCTAssertEqual(object.programmedTempBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 1.5))
            XCTAssertEqual(object.reason, .basal)
            XCTAssertEqual(object.createdAt, dateFormatter.date(from: "2020-01-02T03:34:06Z")!)
        }
    }

    func testCreateWithUUIDAndWithoutOptional() {
        let metadata: [String: Any] = [
            HKMetadataKeyInsulinDeliveryReason: HKInsulinDeliveryReason.bolus.rawValue,
        ]
        let sample = HKQuantitySample(type: HKQuantityType.quantityType(forIdentifier: .insulinDelivery)!,
                                      quantity: HKQuantity(unit: .internationalUnit(), doubleValue: 2.25),
                                      start: dateFormatter.date(from: "2020-02-03T04:05:06Z")!,
                                      end: dateFormatter.date(from: "2020-02-03T04:05:36Z")!,
                                      metadata: metadata)
        cacheStore.managedObjectContext.performAndWait {
            let object = CachedInsulinDeliveryObject(context: cacheStore.managedObjectContext)
            object.create(fromExisting: sample, on: dateFormatter.date(from: "2020-02-03T04:05:37Z")!)
            XCTAssertEqual(object.uuid, sample.uuid)
            XCTAssertEqual(object.provenanceIdentifier, "") // Not yet persisted so HealthKit reports as empty string
            XCTAssertEqual(object.hasLoopKitOrigin, false)
            XCTAssertEqual(object.startDate, dateFormatter.date(from: "2020-02-03T04:05:06Z")!)
            XCTAssertEqual(object.endDate, dateFormatter.date(from: "2020-02-03T04:05:36Z")!)
            XCTAssertEqual(object.syncIdentifier, sample.uuid.uuidString)
            XCTAssertEqual(object.value, 2.25)
            XCTAssertNil(object.scheduledBasalRate)
            XCTAssertNil(object.programmedTempBasalRate)
            XCTAssertEqual(object.reason, .bolus)
            XCTAssertEqual(object.createdAt, dateFormatter.date(from: "2020-02-03T04:05:37Z")!)
        }
    }

    private let dateFormatter = ISO8601DateFormatter()
}

class CachedInsulinDeliveryObjectConstraintTests: PersistenceControllerTestCase {
    func testUUIDUniqueConstraintPreSave() {
        cacheStore.managedObjectContext.performAndWait {
            let uuid = UUID()

            let object1 = CachedInsulinDeliveryObject(context: cacheStore.managedObjectContext)
            object1.setDefaultValues()
            object1.uuid = uuid
            object1.syncIdentifier = "object1"

            let object2 = CachedInsulinDeliveryObject(context: cacheStore.managedObjectContext)
            object2.setDefaultValues()
            object2.uuid = uuid
            object2.syncIdentifier = "object2"

            try! cacheStore.managedObjectContext.save()

            let objects: [CachedInsulinDeliveryObject] = cacheStore.managedObjectContext.all()
            XCTAssertEqual(1, objects.count)
        }
    }

    func testUUIDUniqueConstraintPostSave() {
        cacheStore.managedObjectContext.performAndWait {
            let uuid = UUID()

            let object1 = CachedInsulinDeliveryObject(context: cacheStore.managedObjectContext)
            object1.setDefaultValues()
            object1.uuid = uuid

            try! cacheStore.managedObjectContext.save()

            let object2 = CachedInsulinDeliveryObject(context: cacheStore.managedObjectContext)
            object2.setDefaultValues()
            object2.uuid = uuid

            try! cacheStore.managedObjectContext.save()

            let objects: [CachedInsulinDeliveryObject] = cacheStore.managedObjectContext.all()
            XCTAssertEqual(1, objects.count)
        }
    }

    func testSyncIdentifierUniqueConstraint() {
        cacheStore.managedObjectContext.performAndWait {
            let uuid = UUID()

            let object1 = CachedInsulinDeliveryObject(context: cacheStore.managedObjectContext)
            object1.setDefaultValues()
            object1.syncIdentifier = uuid.uuidString

            try! cacheStore.managedObjectContext.save()

            let object2 = CachedInsulinDeliveryObject(context: cacheStore.managedObjectContext)
            object2.setDefaultValues()
            object2.syncIdentifier = uuid.uuidString

            try! cacheStore.managedObjectContext.save()

            let objects: [CachedInsulinDeliveryObject] = cacheStore.managedObjectContext.all()
            XCTAssertEqual(1, objects.count)
        }
    }

    func testSaveWithDefaultValues() {
        cacheStore.managedObjectContext.performAndWait {
            let object1 = CachedInsulinDeliveryObject(context: cacheStore.managedObjectContext)
            object1.setDefaultValues()

            try! cacheStore.managedObjectContext.save()

            let object2 = CachedInsulinDeliveryObject(context: cacheStore.managedObjectContext)
            object2.setDefaultValues()

            try! cacheStore.managedObjectContext.save()

            let objects: [CachedInsulinDeliveryObject] = cacheStore.managedObjectContext.all()
            XCTAssertEqual(2, objects.count)
        }
    }
}

extension CachedInsulinDeliveryObject {
    fileprivate func setDefaultValues() {
        self.uuid = UUID()
        self.provenanceIdentifier = "CachedInsulinDeliveryObjectTests"
        self.hasLoopKitOrigin = true
        self.startDate = Date()
        self.endDate =  Date()
        self.syncIdentifier = UUID().uuidString
        self.value = 3.5
        self.scheduledBasalRate = nil
        self.programmedTempBasalRate = nil
        self.reason = .basal
        self.createdAt = Date()
    }
}

