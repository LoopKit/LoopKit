//
//  CoreDataMigrationTests.swift
//  LoopKitHostedTests
//
//  Created by Rick Pasetto on 8/9/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

// based on https://ifcaselet.com/writing-unit-tests-for-core-data-migrations/

import CoreData
import HealthKit
import XCTest
@testable import LoopKit

class CoreDataMigrationTests: XCTestCase {
    
    private let momdURL = Bundle(for: PersistenceController.self).url(forResource: "Model", withExtension: "momd")!
    private let storeType = NSSQLiteStoreType
    
    func testV4toV5Migration() throws {
        // create model V4
        let modelV4Container = try startPersistentContainer(.v4)
        
        let modelV4CachedInsulinDeliveryObjectDescription = NSEntityDescription.entity(forEntityName: "CachedInsulinDeliveryObject", in: modelV4Container.viewContext)!
        XCTAssertTrue(modelV4CachedInsulinDeliveryObjectDescription.propertiesByName.keys.contains("value"))
        XCTAssertFalse(modelV4CachedInsulinDeliveryObjectDescription.propertiesByName.keys.contains("deliveredUnits"))
        XCTAssertFalse(modelV4CachedInsulinDeliveryObjectDescription.propertiesByName.keys.contains("programmedUnits"))
        
        let modelV4CachedCarbObjectDescription = NSEntityDescription.entity(forEntityName: "CachedCarbObject", in: modelV4Container.viewContext)!
        XCTAssertFalse(modelV4CachedCarbObjectDescription.propertiesByName.keys.contains("favoriteFoodID"))
        
        // migrate V4 -> V5
        let modelV5Container = try migrate(container: modelV4Container, to: .v5)
        
        let modelV5CachedInsulinDeliveryObjectDescription = NSEntityDescription.entity(forEntityName: "CachedInsulinDeliveryObject", in: modelV5Container.viewContext)!
        XCTAssertFalse(modelV5CachedInsulinDeliveryObjectDescription.propertiesByName.keys.contains("value"))
        XCTAssertTrue(modelV5CachedInsulinDeliveryObjectDescription.propertiesByName.keys.contains("deliveredUnits"))
        XCTAssertTrue(modelV5CachedInsulinDeliveryObjectDescription.propertiesByName.keys.contains("programmedUnits"))
        
        let modelV5CachedCarbObjectDescription = NSEntityDescription.entity(forEntityName: "CachedCarbObject", in: modelV5Container.viewContext)!
        XCTAssertTrue(modelV5CachedCarbObjectDescription.propertiesByName.keys.contains("favoriteFoodID"))
    }
    
    func testV5toV6Migration() throws {
        // create model V5
        let modelV5Container = try startPersistentContainer(.v5)
        let oldContext = modelV5Container.viewContext

        let date = Date()
        let id = UUID()
        let mock = StoredDosingDecision(id: id, reason: "test")
        let encoded = try PropertyListEncoder().encode(mock)

        let oldObject = NSEntityDescription.insertNewObject(forEntityName: "DosingDecisionObject", into: oldContext)
        oldObject.setValue(encoded, forKey: "data")
        oldObject.setValue(date, forKey: "date")
        try oldContext.save()
        
        let v5Count = try modelV5Container.viewContext.count(for: NSFetchRequest<NSManagedObject>(entityName: "DosingDecisionObject"))
        XCTAssertEqual(v5Count, 1)

        let modelV6Container = try migrate(container: modelV5Container, to: .v6, manualMigrationPlan: .v5Tov6)

        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "DosingDecisionObject")
        let migratedObjects = try modelV6Container.viewContext.fetch(fetchRequest)
        XCTAssertEqual(migratedObjects.count, 1)

        if let migratedObject = migratedObjects.first {
            let dateValue = migratedObject.value(forKey: "date") as? Date
            let dataValue = migratedObject.value(forKey: "data") as? Data
            let idValue = migratedObject.value(forKey: "id") as? UUID
            XCTAssertEqual(dateValue, date)
            XCTAssertEqual(dataValue, encoded)
            XCTAssertEqual(idValue, id)
        }
    }
    
    func testV4toV6Migration() throws {
        // create model V4
        let modelV4Container = try startPersistentContainer(.v4)
        let oldContext = modelV4Container.viewContext

        let date = Date()
        let id = UUID()
        let mock = StoredDosingDecision(id: id, reason: "test")
        let encoded = try PropertyListEncoder().encode(mock)

        let oldObject = NSEntityDescription.insertNewObject(forEntityName: "DosingDecisionObject", into: oldContext)
        oldObject.setValue(encoded, forKey: "data")
        oldObject.setValue(date, forKey: "date")
        try oldContext.save()
        
        let v5Count = try modelV4Container.viewContext.count(for: NSFetchRequest<NSManagedObject>(entityName: "DosingDecisionObject"))
        XCTAssertEqual(v5Count, 1)

        let modelV6Container = try migrate(container: modelV4Container, to: .v6, manualMigrationPlan: .v5Tov6)

        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "DosingDecisionObject")
        let migratedObjects = try modelV6Container.viewContext.fetch(fetchRequest)
        XCTAssertEqual(migratedObjects.count, 1)

        if let migratedObject = migratedObjects.first {
            let dateValue = migratedObject.value(forKey: "date") as? Date
            let dataValue = migratedObject.value(forKey: "data") as? Data
            let idValue = migratedObject.value(forKey: "id") as? UUID
            XCTAssertEqual(dateValue, date)
            XCTAssertEqual(dataValue, encoded)
            XCTAssertEqual(idValue, id)
        }
    }
}
    
// taken from https://ifcaselet.com/writing-unit-tests-for-core-data-migrations/
extension CoreDataMigrationTests {
    
    enum ModelVersion {
        case v4
        case v5
        case v6
        
        var name: String {
            switch self {
            case .v4: "Modelv4"
            case .v5: "Modelv5"
            case .v6: "Modelv6"
            }
        }
    }
    
    enum ManualMigrationPlan {
        case v5Tov6
        case v4Tov6
        
        var from: ModelVersion {
            switch self {
            case .v5Tov6:
                return .v5
            case.v4Tov6:
                return .v4
            }
        }
        
        var to: ModelVersion {
            switch self {
            case .v5Tov6, .v4Tov6:
                return .v6
            }
        }
    }
    
    /// Create and load a store using the given model version. The store will be located in a
    /// temporary directory.
    ///
    /// - Parameter versionName: The name of the model (`.xcdatamodel`). For example, `"App V1"`.
    /// - Returns: An `NSPersistentContainer` that is loaded and ready for usage.
    func startPersistentContainer(_ version: ModelVersion, storeURL: URL? = nil) throws -> NSPersistentContainer {
        let storeURL = storeURL ?? makeTemporaryStoreURL()
        let model = managedObjectModel(version: version)

        let container = NSPersistentContainer(name: version.name, managedObjectModel: model)

        let description = NSPersistentStoreDescription(url: storeURL)
        description.type = NSSQLiteStoreType
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = false
        description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)

        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        let semaphore = DispatchSemaphore(value: 0)
        container.loadPersistentStores { _, error in
            loadError = error
            semaphore.signal()
        }
        semaphore.wait()

        if let error = loadError {
            XCTFail("Failed to load persistent store for version \(version.name): \(error)")
            throw error
        }

        return container
    }
    
    /// Migrates the given `container` to a new store URL. The new (migrated) store will be located
    /// in a temporary directory.
    ///
    /// - Parameter container: The `NSPersistentContainer` containing the source store that will be
    ///                        migrated.
    /// - Parameter versionName: The name of the model (`.xcdatamodel`) to migrate to. For example,
    ///                          `"App V2"`.
    ///
    /// - Returns: A migrated `NSPersistentContainer` that is loaded and ready for usage. This
    ///            container uses a different store URL than the original `container`.
    func migrate(container: NSPersistentContainer, to version: ModelVersion, manualMigrationPlan: ManualMigrationPlan? = nil) throws -> NSPersistentContainer {
        // Define the source and destination `NSManagedObjectModels`.
        let sourceModel = container.managedObjectModel
        let destinationModel = managedObjectModel(version: version)
        
        let sourceStoreURL = storeURL(from: container)
        // Create a new temporary store URL. This is where the migrated data using the model
        // will be located.
        let destinationStoreURL = makeTemporaryStoreURL()
        
        // Infer a mapping model between the source and destination `NSManagedObjectModels`.
        // Modify this line if you use a custom mapping model.
        var mappingModel: NSMappingModel
        if manualMigrationPlan != nil {
            let bundle = Bundle(for: PersistenceController.self)
            mappingModel = NSMappingModel(from: [bundle], forSourceModel: sourceModel, destinationModel: destinationModel)!
        } else {
            mappingModel = try NSMappingModel.inferredMappingModel(forSourceModel: sourceModel,
                                                                       destinationModel: destinationModel)
        }
        
        let migrationManager = NSMigrationManager(sourceModel: sourceModel,
                                                  destinationModel: destinationModel)
        // Migrate the `sourceStoreURL` to `destinationStoreURL`.
        try migrationManager.migrateStore(from: sourceStoreURL,
                                          sourceType: storeType,
                                          options: nil,
                                          with: mappingModel,
                                          toDestinationURL: destinationStoreURL,
                                          destinationType: storeType,
                                          destinationOptions: nil)
        
        // Load the store at `destinationStoreURL` and return the migrated container.
        let destinationContainer = makePersistentContainer(storeURL: destinationStoreURL,
                                                           managedObjectModel: destinationModel)
        destinationContainer.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
        
        return destinationContainer
    }
    
    private func makePersistentContainer(storeURL: URL,
                                         managedObjectModel: NSManagedObjectModel) -> NSPersistentContainer {
        let description = NSPersistentStoreDescription(url: storeURL)
        // In order to have more control over when the migration happens, we're setting
        // `shouldMigrateStoreAutomatically` to `false` to stop `NSPersistentContainer`
        // from **automatically** migrating the store. Leaving this as `true` might result in false positives.
        description.shouldMigrateStoreAutomatically = false
        description.type = storeType
        
        let container = NSPersistentContainer(name: "App Container", managedObjectModel: managedObjectModel)
        container.persistentStoreDescriptions = [description]
        
        return container
    }
    
    private func managedObjectModel(version: ModelVersion) -> NSManagedObjectModel {
        let url = momdURL.appendingPathComponent(version.name).appendingPathExtension("mom")
        return NSManagedObjectModel(contentsOf: url)!
    }
    
    private func storeURL(from container: NSPersistentContainer) -> URL {
        let description = container.persistentStoreDescriptions.first!
        return description.url!
    }
    
    private func makeTemporaryStoreURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
    }
}
