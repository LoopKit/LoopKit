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
        let modelV4Container = try startPersistentContainer("Modelv4")
        
        let modelV4CachedInsulinDeliveryObjectDescription = NSEntityDescription.entity(forEntityName: "CachedInsulinDeliveryObject", in: modelV4Container.viewContext)!
        XCTAssertTrue(modelV4CachedInsulinDeliveryObjectDescription.propertiesByName.keys.contains("value"))
        XCTAssertFalse(modelV4CachedInsulinDeliveryObjectDescription.propertiesByName.keys.contains("deliveredUnits"))
        XCTAssertFalse(modelV4CachedInsulinDeliveryObjectDescription.propertiesByName.keys.contains("programmedUnits"))
        
        let modelV4CachedCarbObjectDescription = NSEntityDescription.entity(forEntityName: "CachedCarbObject", in: modelV4Container.viewContext)!
        XCTAssertFalse(modelV4CachedCarbObjectDescription.propertiesByName.keys.contains("favoriteFoodID"))
        
        // migrate V4 -> V5
        let modelV5Container = try migrate(container: modelV4Container, to: "Modelv5")
        
        let modelV5CachedInsulinDeliveryObjectDescription = NSEntityDescription.entity(forEntityName: "CachedInsulinDeliveryObject", in: modelV5Container.viewContext)!
        XCTAssertFalse(modelV5CachedInsulinDeliveryObjectDescription.propertiesByName.keys.contains("value"))
        XCTAssertTrue(modelV5CachedInsulinDeliveryObjectDescription.propertiesByName.keys.contains("deliveredUnits"))
        XCTAssertTrue(modelV5CachedInsulinDeliveryObjectDescription.propertiesByName.keys.contains("programmedUnits"))
        
        let modelV5CachedCarbObjectDescription = NSEntityDescription.entity(forEntityName: "CachedCarbObject", in: modelV5Container.viewContext)!
        XCTAssertTrue(modelV5CachedCarbObjectDescription.propertiesByName.keys.contains("favoriteFoodID"))

    }
}
    
// taken from https://ifcaselet.com/writing-unit-tests-for-core-data-migrations/
extension CoreDataMigrationTests {
    /// Create and load a store using the given model version. The store will be located in a
    /// temporary directory.
    ///
    /// - Parameter versionName: The name of the model (`.xcdatamodel`). For example, `"App V1"`.
    /// - Returns: An `NSPersistentContainer` that is loaded and ready for usage.
    func startPersistentContainer(_ versionName: String) throws -> NSPersistentContainer {
        let storeURL = makeTemporaryStoreURL()
        let model = managedObjectModel(versionName: versionName)
        
        let container = makePersistentContainer(storeURL: storeURL,
                                                managedObjectModel: model)
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
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
    func migrate(container: NSPersistentContainer, to versionName: String) throws -> NSPersistentContainer {
        // Define the source and destination `NSManagedObjectModels`.
        let sourceModel = container.managedObjectModel
        let destinationModel = managedObjectModel(versionName: versionName)
        
        let sourceStoreURL = storeURL(from: container)
        // Create a new temporary store URL. This is where the migrated data using the model
        // will be located.
        let destinationStoreURL = makeTemporaryStoreURL()
        
        // Infer a mapping model between the source and destination `NSManagedObjectModels`.
        // Modify this line if you use a custom mapping model.
        let mappingModel = try NSMappingModel.inferredMappingModel(forSourceModel: sourceModel,
                                                                   destinationModel: destinationModel)
        
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
    
    private func managedObjectModel(versionName: String) -> NSManagedObjectModel {
        let url = momdURL.appendingPathComponent(versionName).appendingPathExtension("mom")
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
