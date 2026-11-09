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

    func testDecisionIdsFallBackToDoseIdWithoutMetadata() async throws {
        let store = DoseMetadataStore(store: cacheStore, expireAfter: .hours(24))
        let newDoseId = UUID()
        let decisionId = UUID()
        let noDecisionDoseId = UUID()
        let legacyDoseId = UUID()

        try await store.storeMetadata(DoseMetadata(origin: .automatic, decisionId: decisionId), for: newDoseId)
        try await store.storeMetadata(DoseMetadata(origin: .remote), for: noDecisionDoseId)

        let decisionIds = try await store.decisionIds(for: [newDoseId, noDecisionDoseId, legacyDoseId])
        XCTAssertEqual(decisionIds, [newDoseId: decisionId, legacyDoseId: legacyDoseId])
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
