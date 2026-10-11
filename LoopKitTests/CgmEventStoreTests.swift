//
//  CgmEventStoreTests.swift
//  LoopKitTests
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import XCTest
import CoreData
import LoopAlgorithm
@testable import LoopKit

class CgmEventStoreTests: PersistenceControllerTestCase {

    var cgmEventStore: CgmEventStore!

    override func setUp() async throws {
        try await super.setUp()
        cgmEventStore = CgmEventStore(cacheStore: cacheStore, cacheLength: .hours(24))
    }

    override func tearDown() async throws {
        cgmEventStore = nil
        try await super.tearDown()
    }

    private func queryEvents() throws -> [PersistedCgmEvent] {
        var events: [PersistedCgmEvent] = []
        var queryError: Error?
        cgmEventStore.executeCgmEventQuery(fromQueryAnchor: nil) { result in
            switch result {
            case .success(_, let stored): events = stored
            case .failure(let error): queryError = error
            }
        }
        if let queryError { throw queryError }
        return events
    }

    func testEventsRoundTrip() async throws {
        let date = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let events = [
            PersistedCgmEvent(date: date, type: .sensorStart, deviceIdentifier: "4A1B2C3D4E", expectedLifetime: .hours(240), warmupPeriod: .minutes(30)),
            PersistedCgmEvent(
                date: date.addingTimeInterval(60),
                type: .calibration,
                deviceIdentifier: "4A1B2C3D4E",
                calibration: CgmCalibration(
                    glucose: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 112),
                    sensorGlucose: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 131)
                )
            ),
            PersistedCgmEvent(date: date.addingTimeInterval(120), type: .sensorError, deviceIdentifier: "4A1B2C3D4E", error: CgmEventError(code: "18", message: "Sensor failed", isFatal: true)),
            PersistedCgmEvent(date: date.addingTimeInterval(180), type: CgmEventType(rawValue: "sensorPaused"), deviceIdentifier: "4A1B2C3D4E", metadata: ["reason": "compression"])
        ]

        try await cgmEventStore.add(events: events)

        XCTAssertEqual(try queryEvents(), events)
    }

    func testEventWithoutDetailsStoresNone() async throws {
        try await cgmEventStore.add(events: [PersistedCgmEvent(date: Date(), type: .sensorStart, deviceIdentifier: "4A1B2C3D4E")])

        let context = cacheStore.managedObjectContext
        let details: [Data?] = try await context.perform {
            try context.fetch(CgmEvent.fetchRequest()).map { $0.details }
        }
        XCTAssertEqual(details, [nil])
    }

    func testDetailsIgnoreUnknownKeys() throws {
        let json = #"{"error":{"message":"Sensor failed","isFatal":false},"addedLater":{"value":1}}"#
        let details = try JSONDecoder().decode(CgmEventDetails.self, from: Data(json.utf8))
        XCTAssertEqual(details.error, CgmEventError(message: "Sensor failed"))
    }
}
