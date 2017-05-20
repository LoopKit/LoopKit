//
//  PersistenceController.swift
//  Naterade
//
//  Inspired by http://martiancraft.com/blog/2015/03/core-data-stack/
//

import CoreData
import UIKit


class PersistenceController {

    enum PersistenceControllerError: Error, LocalizedError {
        case configurationError(String)
        case coreDataError(NSError)

        var errorDescription: String? {
            switch self {
            case .configurationError(let description):
                return description
            case .coreDataError(let error):
                return error.localizedDescription
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .configurationError:
                return "Unrecoverable Error"
            case .coreDataError(let error):
                return error.localizedRecoverySuggestion
            }
        }
    }

    let managedObjectContext: NSManagedObjectContext

    init(databasePath: String, readyCallback: @escaping (_ error: PersistenceControllerError?) -> Void) {
        managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        managedObjectContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy

        initializeStack(atPath: databasePath, readyCallback)
    }

    func save(_ completion: ((_ error: PersistenceControllerError?) -> Void)? = nil) {
        self.managedObjectContext.perform { [unowned self] in
            do {
                if self.managedObjectContext.hasChanges {
                    try self.managedObjectContext.save()
                }

                completion?(nil)
            } catch let saveError as NSError {
                completion?(.coreDataError(saveError))
            }
        }
    }

    // MARK: - 

    private func initializeStack(atPath path: String, _ readyCallback: @escaping (_ error: PersistenceControllerError?) -> Void) {
        managedObjectContext.perform {
            var error: PersistenceControllerError?

            let modelURL = Bundle(for: type(of: self)).url(forResource: "Model", withExtension: "momd")!
            let model = NSManagedObjectModel(contentsOf: modelURL)!
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)

            self.managedObjectContext.persistentStoreCoordinator = coordinator

            if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(path, isDirectory: true)
            {
                if !FileManager.default.fileExists(atPath: documentsURL.absoluteString) {
                    do {
                        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true, attributes: nil)
                    } catch {
                        // Ignore errors here, let Core Data explain the problem
                    }
                }

                let storeURL = documentsURL.appendingPathComponent("Model.sqlite")

                do {
                    try coordinator.addPersistentStore(ofType: NSSQLiteStoreType,
                        configurationName: nil,
                        at: storeURL,
                        options: [
                            NSMigratePersistentStoresAutomaticallyOption: true,
                            NSInferMappingModelAutomaticallyOption: true,
                            // Data should be available on reboot before first unlock
                            NSPersistentStoreFileProtectionKey: FileProtectionType.none
                        ]
                    )
                } catch let storeError as NSError {
                    error = .coreDataError(storeError)
                }
            } else {
                error = .configurationError("Cannot configure persistent store for path: \(path) in directory: \(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask))")
            }

            readyCallback(error)
        }
    }
}
