//
//  PersistenceController.swift
//  Naterade
//
//  Inspired by http://martiancraft.com/blog/2015/03/core-data-stack/
//

import CoreData


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

    public init(directoryURL: URL) {
        managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        managedObjectContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy

        initializeStack(inDirectory: directoryURL)
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

    private func initializeStack(inDirectory directoryURL: URL) {
        managedObjectContext.perform {
            var error: PersistenceControllerError?

            let modelURL = Bundle(for: type(of: self)).url(forResource: "Model", withExtension: "momd")!
            let model = NSManagedObjectModel(contentsOf: modelURL)
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model!)

            self.managedObjectContext.persistentStoreCoordinator = coordinator

            if !FileManager.default.fileExists(atPath: directoryURL.absoluteString) {
                do {
                    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
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
