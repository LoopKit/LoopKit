//
//  PersistenceController.swift
//  Naterade
//
//  Inspired by http://martiancraft.com/blog/2015/03/core-data-stack/
//

import CoreData
import os.log


public protocol PersistenceControllerDelegate: class {
    /// Informs the delegate that a save operation will start, so it can start a background task on its behalf
    ///
    /// - Parameter controller: The persistence controller
    func persistenceControllerWillSave(_ controller: PersistenceController)

    /// Informs the delegate that a save operation did end
    ///
    /// - Parameters:
    ///   - controller: The persistence controller
    ///   - error: An error describing why the save failed
    func persistenceControllerDidSave(_ controller: PersistenceController, error: PersistenceController.PersistenceControllerError?)
}


/// Provides a Core Data persistence stack for the LoopKit data model
public final class PersistenceController {

    public enum PersistenceControllerError: Error, LocalizedError {
        case configurationError(String)
        case coreDataError(NSError)

        public var errorDescription: String? {
            switch self {
            case .configurationError(let description):
                return description
            case .coreDataError(let error):
                return error.localizedDescription
            }
        }

        public var recoverySuggestion: String? {
            switch self {
            case .configurationError:
                return "Unrecoverable Error"
            case .coreDataError(let error):
                return error.localizedRecoverySuggestion
            }
        }
    }

    private enum ReadyState {
        case waiting
        case ready
        case error(PersistenceControllerError)
    }

    public typealias ReadyCallback = (_ error: PersistenceControllerError?) -> Void

    internal let managedObjectContext: NSManagedObjectContext

    public let isReadOnly: Bool

    public let directoryURL: URL

    public weak var delegate: PersistenceControllerDelegate?

    private let log = OSLog(category: "PersistenceController")

    /// Initializes a new persistence controller in the specified directory
    ///
    /// - Parameters:
    ///   - directoryURL: The directory where the SQLlite database is stored. Will be created with no file protection if it doesn't exist.
    ///   - model: The managed object model definition
    ///   - isReadOnly: Whether the persistent store is intended to be read-only. Read-only stores will observe cross-process notifications and reload all contexts when data changes. Writable stores will post these notifications.
    public init(
        directoryURL: URL,
        model: NSManagedObjectModel = NSManagedObjectModel(contentsOf: Bundle(for: PersistenceController.self).url(forResource: "Model", withExtension: "momd")!)!,
        isReadOnly: Bool = false
    ) {
        managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        managedObjectContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        managedObjectContext.automaticallyMergesChangesFromParent = true

        self.directoryURL = directoryURL
        self.isReadOnly = isReadOnly

        initializeStack(inDirectory: directoryURL, model: model)
    }

    private var readyCallbacks: [ReadyCallback] = []

    private var readyState: ReadyState = .waiting

    private var queue = DispatchQueue(label: "com.loopkit.PersistenceController", qos: .utility)

    func onReady(_ callback: @escaping ReadyCallback) {
        queue.async {
            switch self.readyState {
            case .waiting:
                self.readyCallbacks.append(callback)
            case .ready:
                callback(nil)
            case .error(let error):
                callback(error)
            }
        }
    }

    @discardableResult
    func save(_ completion: ((_ error: PersistenceControllerError?) -> Void)? = nil) -> PersistenceControllerError? {
        var error: PersistenceControllerError?

        self.managedObjectContext.performAndWait {
            guard !self.isReadOnly && self.managedObjectContext.hasChanges else {
                completion?(nil)
                return
            }

            do {
                delegate?.persistenceControllerWillSave(self)
                try self.managedObjectContext.save()
                delegate?.persistenceControllerDidSave(self, error: nil)
                completion?(nil)
            } catch let saveError as NSError {
                self.log.error("Error while saving context: %{public}@", saveError)
                error = .coreDataError(saveError)
                delegate?.persistenceControllerDidSave(self, error: error)
                completion?(error)
            }
        }

        return error
    }

    // MARK: - 

    private func initializeStack(inDirectory directoryURL: URL, model: NSManagedObjectModel) {
        managedObjectContext.perform {
            var error: PersistenceControllerError?

            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)

            self.managedObjectContext.persistentStoreCoordinator = coordinator

            if !FileManager.default.fileExists(atPath: directoryURL.absoluteString) {
                do {
                    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: [FileAttributeKey.protectionKey: FileProtectionType.none])
                } catch {
                    // Ignore errors here, let Core Data explain the problem
                }
            }

            let storeURL = directoryURL.appendingPathComponent("Model.sqlite")

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
                self.log.error("Failed to initialize persistenceController: %{public}@", storeError)
                error = .coreDataError(storeError)
            }

            self.queue.async {
                if let error = error {
                    self.readyState = .error(error)
                } else {
                    self.readyState = .ready
                }

                for callback in self.readyCallbacks {
                    callback(error)
                }

                self.readyCallbacks = []
            }
        }
    }
}


extension PersistenceController: CustomDebugStringConvertible {
    public var debugDescription: String {
        return [
            "## PersistenceController",
            "* isReadOnly: \(isReadOnly)",
            "* directoryURL: \(directoryURL)",
            "* persistenceStoreCoordinator: \(String(describing: managedObjectContext.persistentStoreCoordinator))",
        ].joined(separator: "\n")
    }
}
