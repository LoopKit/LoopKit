//
//  DoseEntryTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 5/4/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest

@testable import LoopKit

class DoseEntryCodableTests: XCTestCase {
    func testCodable() throws {
        try assertDoseEntryCodable(DoseEntry(type: .bolus,
                                             startDate: dateFormatter.date(from: "2020-05-14T22:07:19Z")!,
                                             value: 2.5,
                                             unit: .units,
                                             doseId: nil),
        encodesJSON: """
{
  "endDate" : "2020-05-14T22:07:19Z",
  "startDate" : "2020-05-14T22:07:19Z",
  "type" : "bolus",
  "unit" : "U",
  "value" : 2.5
}
"""
        )
    }

    func testCodableOptional() throws {
        try assertDoseEntryCodable(DoseEntry(type: .tempBasal,
                                             startDate: dateFormatter.date(from: "2020-05-14T22:07:19Z")!,
                                             endDate: dateFormatter.date(from: "2020-05-14T22:37:19Z")!,
                                             value: 1.25,
                                             unit: .unitsPerHour,
                                             doseId: nil,
                                             deliveredUnits: 0.5,
                                             description: "Temporary Basal",
                                             syncIdentifier: "238E41EA-9576-4981-A1A4-51E10228584F",
                                             scheduledBasalRate: LoopQuantity(unit: DoseEntry.unitsPerHour, doubleValue: 1.5),
                                             insulinType: .fiasp,
                                             automatic: true,
                                             manuallyEntered: true,
                                             isMutable: true,
                                             wasProgrammedByPumpUI: true),
                                   encodesJSON: """
{
  "automatic" : true,
  "deliveredUnits" : 0.5,
  "description" : "Temporary Basal",
  "endDate" : "2020-05-14T22:37:19Z",
  "insulinType" : 3,
  "isMutable" : true,
  "manuallyEntered" : true,
  "scheduledBasalRate" : 1.5,
  "scheduledBasalRateUnit" : "IU/hr",
  "startDate" : "2020-05-14T22:07:19Z",
  "syncIdentifier" : "238E41EA-9576-4981-A1A4-51E10228584F",
  "type" : "tempBasal",
  "unit" : "U/hour",
  "value" : 1.25,
  "wasProgrammedByPumpUI" : true
}
"""
        )
    }
    
    private func assertDoseEntryCodable(_ original: DoseEntry, encodesJSON string: String) throws {
        let data = try encoder.encode(original)
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
        let decoded = try decoder.decode(DoseEntry.self, from: data)
        XCTAssertEqual(decoded, original)
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

class DoseEntryRawRepresentableTests: XCTestCase {
    func testDoseEntryRawRepresentable() {
        let original = DoseEntry(type: .bolus,
                                 startDate: Date(),
                                 value: 2.5,
                                 unit: .units,
                                 doseId: nil)
        let actual = DoseEntry(rawValue: original.rawValue)
        XCTAssertEqual(actual, original)
    }

    func testDoseEntryRawRepresentableOptional() {
        let original = DoseEntry(type: .tempBasal,
                                 startDate: Date(),
                                 endDate: Date().addingTimeInterval(.minutes(30)),
                                 value: 1.25,
                                 unit: .unitsPerHour,
                                 doseId: nil,
                                 deliveredUnits: 0.5,
                                 description: "Temporary Basal",
                                 syncIdentifier: UUID().uuidString,
                                 scheduledBasalRate: LoopQuantity(unit: .internationalUnitsPerHour, doubleValue: 1.5),
                                 insulinType: .fiasp,
                                 automatic: true,
                                 manuallyEntered: true,
                                 isMutable: true,
                                 wasProgrammedByPumpUI: true)
        let actual = DoseEntry(rawValue: original.rawValue)
        XCTAssertEqual(actual, original)
    }

    func testLegacyDecisionIdBecomesDoseId() throws {
        let id = UUID()
        var rawValue = DoseEntry(type: .bolus, startDate: Date(), value: 1, unit: .units).rawValue
        rawValue["decisionId"] = id.uuidString
        XCTAssertEqual(DoseEntry(rawValue: rawValue)?.doseId, id)

        let json = #"{"type":"bolus","startDate":"2026-11-09T12:00:00Z","endDate":"2026-11-09T12:00:00Z","value":1,"unit":"U","decisionId":"\#(id.uuidString)"}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertEqual(try decoder.decode(DoseEntry.self, from: Data(json.utf8)).doseId, id)
    }

    func testMetadataRoundTrips() throws {
        let original = DoseEntry(type: .bolus,
                                 startDate: Date(),
                                 value: 2,
                                 unit: .units,
                                 doseId: UUID(),
                                 metadata: DoseMetadata(origin: .user, device: .watch, decisionId: UUID(), activationType: .manualRecommendationAccepted))

        XCTAssertEqual(DoseEntry(rawValue: original.rawValue), original)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DoseEntry.self, from: encoder.encode(original))
        XCTAssertEqual(decoded.metadata, original.metadata)
    }

    func testDecisionIdFallsBackToDoseIdWithoutMetadata() {
        let decisionId = UUID()
        let doseId = UUID()
        let withDecision = DoseEntry(type: .bolus, startDate: Date(), value: 1, unit: .units, doseId: doseId, metadata: DoseMetadata(origin: .user, decisionId: decisionId))
        let remote = DoseEntry(type: .bolus, startDate: Date(), value: 1, unit: .units, doseId: doseId, metadata: DoseMetadata(origin: .remote))
        let legacy = DoseEntry(type: .bolus, startDate: Date(), value: 1, unit: .units, doseId: doseId)

        XCTAssertEqual(withDecision.decisionId, decisionId)
        XCTAssertNil(remote.decisionId)
        XCTAssertEqual(legacy.decisionId, doseId)
    }

    func testRemoteRequestRoundTrips() throws {
        let request = DoseMetadata.RemoteRequest(serviceIdentifier: "LoopSight", requestId: "cmd-1", requester: "Mom", requestedAt: Date(timeIntervalSince1970: 1_800_000_000), approvedBy: .init())
        let metadata = DoseMetadata(origin: .remote, activationType: .manualNoRecommendation, remoteRequest: request)

        XCTAssertEqual(try DoseMetadata(encoded: metadata.encoded()), metadata)
    }

    func testMetadataDecodesUnknownValues() throws {
        let json = #"{"origin":"siri","device":"ring","activationType":"voice","decisionId":"\#(UUID().uuidString)","remoteRequest":{"serviceIdentifier":"X","approvedBy":{"name":"Dad"},"future":1}}"#
        let metadata = try JSONDecoder().decode(DoseMetadata.self, from: Data(json.utf8))

        XCTAssertEqual(metadata.origin, .unknown)
        XCTAssertNil(metadata.device)
        XCTAssertNil(metadata.activationType)
        XCTAssertNotNil(metadata.decisionId)
        XCTAssertEqual(metadata.remoteRequest, DoseMetadata.RemoteRequest(serviceIdentifier: "X", approvedBy: .init(name: "Dad")))
    }
}
