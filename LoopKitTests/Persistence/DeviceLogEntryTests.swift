//
//  DeviceLogEntryTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 8/26/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import CoreData
@testable import LoopKit

class DeviceLogEntryEncodableTests: XCTestCase {
    private var persistentContainer: NSPersistentContainer!
    private var managedObjectContext: NSManagedObjectContext!

    override func setUp() {
        super.setUp()

        let persistentStoreDescription = NSPersistentStoreDescription()
        persistentStoreDescription.type = NSInMemoryStoreType

        persistentContainer = PersistentContainer(name: "DeviceLog")
        persistentContainer.persistentStoreDescriptions = [persistentStoreDescription]
        persistentContainer.loadPersistentStores { (_, _) in }

        managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        managedObjectContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        managedObjectContext.automaticallyMergesChangesFromParent = true
        managedObjectContext.persistentStoreCoordinator = persistentContainer.persistentStoreCoordinator
    }

    override func tearDown() {
        managedObjectContext = nil
        persistentContainer = nil

        super.tearDown()
    }

    func testEncodable() throws {
        managedObjectContext.performAndWait {
            let deviceLogEntry = DeviceLogEntry(context: managedObjectContext)
            deviceLogEntry.type = .connection
            deviceLogEntry.managerIdentifier = "238E41EA-9576-4981-A1A4-51E10228584F"
            deviceLogEntry.deviceIdentifier = "7723A0EE-F6D5-46E0-BBFE-1DEEBF8ED6F2"
            deviceLogEntry.message = "This is the message"
            deviceLogEntry.timestamp = dateFormatter.date(from: "2020-05-14T22:38:14Z")!
            deviceLogEntry.modificationCounter = 123
            try! assertDeviceLogEntryEncodable(deviceLogEntry, encodesJSON: """
{
  "deviceIdentifier" : "7723A0EE-F6D5-46E0-BBFE-1DEEBF8ED6F2",
  "managerIdentifier" : "238E41EA-9576-4981-A1A4-51E10228584F",
  "message" : "This is the message",
  "modificationCounter" : 123,
  "timestamp" : "2020-05-14T22:38:14Z",
  "type" : "connection"
}
"""
            )
        }
    }

    func testEncodableOptional() throws {
        managedObjectContext.performAndWait {
            let deviceLogEntry = DeviceLogEntry(context: managedObjectContext)
            deviceLogEntry.modificationCounter = 234
            try! assertDeviceLogEntryEncodable(deviceLogEntry, encodesJSON: """
{
  "modificationCounter" : 234
}
"""
            )
        }
    }

    private func assertDeviceLogEntryEncodable(_ original: DeviceLogEntry, encodesJSON string: String) throws {
        let data = try encoder.encode(original)
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
    }

    private let dateFormatter = ISO8601DateFormatter()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
