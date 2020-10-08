//
//  PersistenceController.swift
//  Naterade
//
//  Inspired by http://martiancraft.com/blog/2015/03/core-data-stack/
//

import CoreData
import os.log
import HealthKit



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
            guard self.managedObjectContext.hasChanges else {
                completion?(nil)
                return
            }

            error = self.saveInternal()
            completion?(error)
        }
        
        return error
    }
    
    // Should only be called from managedObjectContext thread
    internal func saveInternal() -> PersistenceControllerError? {
        guard !self.isReadOnly else {
            return nil
        }

        do {
            delegate?.persistenceControllerWillSave(self)
            try self.managedObjectContext.save()
            delegate?.persistenceControllerDidSave(self, error: nil)
            return nil
        } catch let saveError as NSError {
            self.log.error("Error while saving context: %{public}@", saveError)
            delegate?.persistenceControllerDidSave(self, error: .coreDataError(saveError))
            return .coreDataError(saveError)
        }
    }


    // Should only be called on managedObjectContext thread
    func updateMetadata(key: String, value: Any?) {
        if let coordinator = self.managedObjectContext.persistentStoreCoordinator, let store = coordinator.persistentStores.first {
            var metadata = coordinator.metadata(for: store)
            metadata[key] = value
            coordinator.setMetadata(metadata, for: store)
        }
    }
    
    // Should only be called on managedObjectContext thread
    func fetchMetadata(key: String) -> Any? {
        if let coordinator = self.managedObjectContext.persistentStoreCoordinator, let store = coordinator.persistentStores.first {
            let metadata = coordinator.metadata(for: store)
            return metadata[key]
        } else {
            return nil
        }
    }
    
    // MARK: - 

    private func initializeStack(inDirectory directoryURL: URL, model: NSManagedObjectModel) {
        managedObjectContext.perform {
            var error: PersistenceControllerError?

            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)

            self.managedObjectContext.persistentStoreCoordinator = coordinator

            do {
                try FileManager.default.ensureDirectoryExists(at: directoryURL, with: FileProtectionType.completeUntilFirstUserAuthentication)
            } catch {
                // Ignore errors here, let Core Data explain the problem
            }

            let storeURL = directoryURL.appendingPathComponent("Model.sqlite")

            do {
                try coordinator.addPersistentStore(ofType: NSSQLiteStoreType,
                    configurationName: nil,
                    at: storeURL,
                    options: [
                        NSMigratePersistentStoresAutomaticallyOption: true,
                        NSInferMappingModelAutomaticallyOption: true,
                        NSPersistentStoreFileProtectionKey: FileProtectionType.completeUntilFirstUserAuthentication
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


// MARK: - Anchor store/fetch helpers

extension PersistenceController {
    func storeAnchor(_ anchor: HKQueryAnchor?, key: String) {
        managedObjectContext.perform {
            let encoded: Data?
            if let anchor = anchor {
                encoded = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
                if encoded == nil {
                    self.log.error("Encoding anchor %{public} failed.", String(describing: anchor))
                }
            } else {
                encoded = nil
            }
            self.updateMetadata(key: key, value: encoded)
            let _ = self.saveInternal()
        }
    }
    
    func fetchAnchor(key: String, completion: @escaping (HKQueryAnchor?) -> Void) {
        managedObjectContext.perform {
            let value = self.fetchMetadata(key: key)
            if let encoded = value as? Data {
                let anchor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: encoded)
                if anchor == nil {
                    self.log.error("Decoding anchor from %{public} failed.", String(describing: encoded))
                }
                completion(anchor)
            } else {
                completion(nil)
            }
        }
    }
}

fileprivate extension FileManager {
    
    func ensureDirectoryExists(at url: URL, with protectionType: FileProtectionType? = nil) throws {
        try createDirectory(at: url, withIntermediateDirectories: true, attributes: protectionType.map { [FileAttributeKey.protectionKey: $0 ] })
        guard let protectionType = protectionType else {
            return
        }
        // double check protection type
        var attrs = try attributesOfItem(atPath: url.path)
        if attrs[FileAttributeKey.protectionKey] as? FileProtectionType != protectionType {
            attrs[FileAttributeKey.protectionKey] = protectionType
            try setAttributes(attrs, ofItemAtPath: url.path)
        }
    }
 
}
