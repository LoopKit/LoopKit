//
//  PersistenceController.swift
//  Naterade
//
//  Inspired by http://martiancraft.com/blog/2015/03/core-data-stack/
//

import CoreData
import UIKit


class PersistenceController {

    enum PersistenceControllerError: Error {
        case configurationError(String)
        case coreDataError(Error)

        // TODO: Drop in favor of `localizedDescription`
        var description: String {
            switch self {
            case .configurationError(let description):
                return description
            case .coreDataError(let error):
                return error.localizedDescription
            }
        }

        var localizedDescription: String {
            return description
        }

        var recoverySuggestion: String {
            switch self {
            case .configurationError:
                return "Unrecoverable Error"
            case .coreDataError(let error):
                return (error as NSError).localizedRecoverySuggestion ?? "Please try again later"
            }
        }
    }

    private let privateManagedObjectContext: NSManagedObjectContext

    var managedObjectContext: NSManagedObjectContext {
        return privateManagedObjectContext
    }

    init(readyCallback: @escaping (_ error: PersistenceControllerError?) -> Void) {
        privateManagedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateManagedObjectContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy

        initializeStack(readyCallback)

        didEnterBackgroundNotificationObserver = NotificationCenter.default.addObserver(forName: .UIApplicationDidEnterBackground, object: UIApplication.shared, queue: nil, using: handleSave)
        willResignActiveNotificationObserver = NotificationCenter.default.addObserver(forName: .UIApplicationWillResignActive, object: UIApplication.shared, queue: nil, using: handleSave)
        willTerminateNotificationObserver = NotificationCenter.default.addObserver(forName: .UIApplicationWillTerminate, object: UIApplication.shared, queue: nil, using: handleSave)
    }

    deinit {
        for observer in [didEnterBackgroundNotificationObserver, willResignActiveNotificationObserver, willTerminateNotificationObserver] where observer != nil {
            NotificationCenter.default.removeObserver(observer!)
        }
    }

    private var didEnterBackgroundNotificationObserver: Any?
    private var willResignActiveNotificationObserver: Any?
    private var willTerminateNotificationObserver: Any?

    private func handleSave(_ note: Notification) {
        var taskID: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid

        taskID = UIApplication.shared.beginBackgroundTask (expirationHandler: { () -> Void in
            UIApplication.shared.endBackgroundTask(taskID)
        })

        if taskID != UIBackgroundTaskInvalid {
            save({ (error) -> Void in
                // Log the error?

                UIApplication.shared.endBackgroundTask(taskID)
            })
        }
    }

    func save(_ completionHandler: @escaping (_ error: PersistenceControllerError?) -> Void) {
        self.privateManagedObjectContext.perform { [unowned self] in
            do {
                if self.privateManagedObjectContext.hasChanges {
                    try self.privateManagedObjectContext.save()
                }

                completionHandler(nil)
            } catch let saveError {
                completionHandler(.coreDataError(saveError))
            }
        }
    }

    // MARK: - 

    private func initializeStack(_ readyCallback: @escaping (_ error: PersistenceControllerError?) -> Void) {
        privateManagedObjectContext.perform {
            var error: PersistenceControllerError?

            let modelURL = Bundle(for: type(of: self)).url(forResource: "Model", withExtension: "momd")!
            let model = NSManagedObjectModel(contentsOf: modelURL)!
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)

            self.privateManagedObjectContext.persistentStoreCoordinator = coordinator

            let bundle = Bundle(for: type(of: self))

            if let  bundleIdentifier = bundle.bundleIdentifier,
                    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(bundleIdentifier, isDirectory: true)
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
                            NSInferMappingModelAutomaticallyOption: true
                        ]
                    )
                } catch let storeError {
                    error = .coreDataError(storeError)
                }
            } else {
                error = .configurationError("Cannot configure persistent store for bundle: \(bundle.bundleIdentifier) in directory: \(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask))")
            }

            readyCallback(error)
        }
    }
}
