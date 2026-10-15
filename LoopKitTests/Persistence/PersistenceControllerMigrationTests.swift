//
//  PersistenceControllerMigrationTests.swift
//  LoopKitTests
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import XCTest
import CoreData
import HealthKit
@testable import LoopKit

class PersistenceControllerMigrationTests: XCTestCase {

    var directoryURL: URL!

    override func setUp() {
        super.setUp()
        directoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directoryURL)
        directoryURL = nil
        super.tearDown()
    }

    func testModelv4StoreMigratesToCurrentModel() throws {
        try createStore(modelNamed: "Modelv4") { context in
            self.insert("CachedInsulinDeliveryObject", into: context, values: [
                "syncIdentifier": "bolus", "value": 2.5, "reason": HKInsulinDeliveryReason.bolus.rawValue
            ])
            self.insert("CachedInsulinDeliveryObject", into: context, values: [
                "syncIdentifier": "tempBasal", "value": 0.4, "reason": HKInsulinDeliveryReason.basal.rawValue, "programmedTempBasalRate": 0.8
            ])
        }

        let cacheStore = try openCacheStore()
        defer { cacheStore.tearDown() }

        let doses = try fetchDoses(in: cacheStore)
        XCTAssertEqual(doses["bolus"]?.type, .bolus)
        XCTAssertEqual(doses["bolus"]?.value, 2.5)
        XCTAssertEqual(doses["tempBasal"]?.type, .tempBasal)
        XCTAssertEqual(doses["tempBasal"]?.unitsPerHour, 0.8)
        XCTAssertEqual(doses["tempBasal"]?.deliveredUnits, 0.4)

        try cacheStore.managedObjectContext.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CachedInsulinDeliveryObject")
            request.predicate = NSPredicate(format: "syncIdentifier == %@", "bolus")
            let bolus = try XCTUnwrap(cacheStore.managedObjectContext.fetch(request).first)
            XCTAssertEqual(bolus.value(forKey: "programmedUnits") as? Double, 2.5)
        }
    }

    func testModelv1StoreMigratesToCurrentModel() throws {
        try createStore(modelNamed: "Model") { context in
            self.insert("CachedCarbObject", into: context, values: ["grams": 30.0, "syncIdentifier": "carb"])
            self.insert("CachedInsulinDeliveryObject", into: context, values: [
                "syncIdentifier": "bolus", "value": 1.5, "reason": HKInsulinDeliveryReason.bolus.rawValue
            ])
        }

        let cacheStore = try openCacheStore()
        defer { cacheStore.tearDown() }

        XCTAssertEqual(try fetchDoses(in: cacheStore)["bolus"]?.value, 1.5)
        try cacheStore.managedObjectContext.performAndWait {
            let carbs = try cacheStore.managedObjectContext.fetch(CachedCarbObject.fetchRequest())
            XCTAssertEqual(carbs.map(\.grams), [30])
        }
    }

    // Core Data keeps the store's model in the store, so it can infer the mapping down to ours
    func testStoreFromNewerModelOpensAndKeepsItsData() throws {
        let newerModel = try bundledModel(named: "Modelv8")
        let attribute = NSAttributeDescription()
        attribute.name = "addedInANewerVersion"
        attribute.attributeType = .stringAttributeType
        attribute.isOptional = true
        let entity = try XCTUnwrap(newerModel.entitiesByName["CachedCarbObject"])
        entity.properties.append(attribute)
        try createStore(model: newerModel) { context in
            self.insert("CachedCarbObject", into: context, values: ["grams": 30.0, "addedInANewerVersion": "x"])
            self.insert("CachedInsulinDeliveryObject", into: context, values: [
                "syncIdentifier": "bolus", "deliveredUnits": 2.5, "programmedUnits": 2.5, "reason": HKInsulinDeliveryReason.bolus.rawValue
            ])
        }

        let cacheStore = try openCacheStore()
        defer { cacheStore.tearDown() }

        XCTAssertEqual(try fetchDoses(in: cacheStore)["bolus"]?.value, 2.5)
        try cacheStore.managedObjectContext.performAndWait {
            let carbs = try cacheStore.managedObjectContext.fetch(CachedCarbObject.fetchRequest())
            XCTAssertEqual(carbs.map(\.grams), [30])
        }
    }

    // MARK: -

    private func bundledModel(named name: String) throws -> NSManagedObjectModel {
        let modelsURL = try XCTUnwrap(Bundle(for: PersistenceController.self).url(forResource: "Model", withExtension: "momd"))
        let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelsURL.appendingPathComponent(name).appendingPathExtension("mom")))
        // Plain objects, so the store is written without running the app's managed object classes
        let plainModel = model.copy() as! NSManagedObjectModel
        plainModel.entities.forEach { $0.managedObjectClassName = NSStringFromClass(NSManagedObject.self) }
        return plainModel
    }

    private func createStore(modelNamed name: String, populate: @escaping (NSManagedObjectContext) -> Void) throws {
        try createStore(model: try bundledModel(named: name), populate: populate)
    }

    private func createStore(model: NSManagedObjectModel, populate: @escaping (NSManagedObjectContext) -> Void) throws {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: directoryURL.appendingPathComponent("Model.sqlite"))
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        try context.performAndWait {
            populate(context)
            try context.save()
        }
        try coordinator.remove(store)
    }

    private func insert(_ entityName: String, into context: NSManagedObjectContext, values: [String: Any]) {
        let object = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
        for (name, attribute) in object.entity.attributesByName where !attribute.isOptional && attribute.defaultValue == nil {
            switch attribute.attributeType {
            case .dateAttributeType: object.setValue(Date(), forKey: name)
            case .stringAttributeType: object.setValue("test", forKey: name)
            case .booleanAttributeType: object.setValue(false, forKey: name)
            case .UUIDAttributeType: object.setValue(UUID(), forKey: name)
            case .binaryDataAttributeType: object.setValue(Data(), forKey: name)
            default: object.setValue(0, forKey: name)
            }
        }
        object.setValuesForKeys(values)
    }

    private func openCacheStore() throws -> PersistenceController {
        let cacheStore = PersistenceController(directoryURL: directoryURL)
        let ready = expectation(description: "ready")
        var readyError: Error?
        cacheStore.onReady { error in
            readyError = error
            ready.fulfill()
        }
        wait(for: [ready], timeout: 10)
        if let readyError {
            throw readyError
        }
        return cacheStore
    }

    private func fetchDoses(in cacheStore: PersistenceController) throws -> [String: DoseEntry] {
        try cacheStore.managedObjectContext.performAndWait {
            let objects = try cacheStore.managedObjectContext.fetch(CachedInsulinDeliveryObject.fetchRequest())
            return Dictionary(uniqueKeysWithValues: objects.map { ($0.syncIdentifier ?? "", $0.dose) })
        }
    }
}
