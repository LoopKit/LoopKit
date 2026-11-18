//
//  DoseMetadataStoreTests.swift
//  LoopKitTests
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit

class DoseMetadataStoreTests: PersistenceControllerTestCase {

    func testStoresAndFetchesMetadataByDoseId() async throws {
        let store = DoseMetadataStore(store: cacheStore, expireAfter: .hours(24))
        let bolusId = UUID()
        let tempBasalId = UUID()
        let decisionId = UUID()
        let bolus = DoseMetadata(origin: .user, device: .watch, decisionId: decisionId, activationType: .manualRecommendationAccepted)
        let tempBasal = DoseMetadata(origin: .automatic, device: .phone, decisionId: decisionId)

        try await store.storeMetadata(bolus, for: bolusId)
        try await store.storeMetadata(tempBasal, for: tempBasalId)

        let fetched = try await store.metadata(for: [bolusId, tempBasalId, UUID()])
        XCTAssertEqual(fetched, [bolusId: bolus, tempBasalId: tempBasal])

        let single = try await store.metadata(for: bolusId)
        XCTAssertEqual(single, bolus)
    }

    func testAddsMetadataToReportedDoses() async throws {
        let store = DoseMetadataStore(store: cacheStore, expireAfter: .hours(24))
        let doseId = UUID()
        let metadata = DoseMetadata(origin: .automatic, device: .phone, decisionId: UUID(), activationType: .automatic)
        try await store.storeMetadata(metadata, for: doseId)

        let now = Date()
        let bolus = NewPumpEvent(date: now, dose: DoseEntry(type: .bolus, startDate: now, value: 1, unit: .units, doseId: doseId, isMutable: true), raw: Data([1]), title: "Bolus")
        let unknown = NewPumpEvent(date: now, dose: DoseEntry(type: .bolus, startDate: now, value: 1, unit: .units, doseId: UUID()), raw: Data([2]), title: "Bolus")
        let suspend = NewPumpEvent(date: now, dose: DoseEntry(suspendDate: now), raw: Data([3]), title: "Suspend")

        let events = await store.addingMetadata(to: [bolus, unknown, suspend])

        XCTAssertEqual(events[0].dose?.metadata, metadata)
        XCTAssertEqual(events[0].dose?.syncIdentifier, bolus.dose?.syncIdentifier)
        XCTAssertEqual(events[0].type, .bolus)
        XCTAssertEqual(events[1], unknown)
        XCTAssertEqual(events[2], suspend)

        // A dose reported again, now final, still gets its metadata.
        let finalBolus = NewPumpEvent(date: now, dose: DoseEntry(type: .bolus, startDate: now, value: 1, unit: .units, doseId: doseId, deliveredUnits: 1), raw: Data([1]), title: "Bolus")
        let finalEvents = await store.addingMetadata(to: [finalBolus])
        XCTAssertEqual(finalEvents[0].dose?.metadata, metadata)
    }

    func testPurgesExpiredMetadata() async throws {
        let store = DoseMetadataStore(store: cacheStore, expireAfter: .hours(24))
        let oldId = UUID()
        let newId = UUID()

        try await store.storeMetadata(DoseMetadata(origin: .remote), for: oldId, date: Date(timeIntervalSinceNow: -.hours(48)))
        try await store.storeMetadata(DoseMetadata(origin: .remote), for: newId)

        let fetched = try await store.metadata(for: [oldId, newId])
        XCTAssertEqual(Set(fetched.keys), [newId])
    }
}
