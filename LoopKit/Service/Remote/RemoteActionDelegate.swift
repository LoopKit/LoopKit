//
//  RemoteActionDelegate.swift
//  LoopKit
//
//  Created by Bill Gestrich on 3/19/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation

public protocol RemoteActionDelegate: AnyObject {
    func enactRemoteOverride(name: String, durationTime: TimeInterval?, remoteAddress: String) async throws
    func cancelRemoteOverride() async throws
    func deliverRemoteCarbs(amountInGrams: Double, absorptionTime: TimeInterval?, foodType: String?, startDate: Date?) async throws
    func deliverRemoteBolus(amountInUnits: Double, decisionId: UUID?) async throws
    /// Delivers a bolus for a remote command; the request is kept in the dose's metadata.
    func deliverRemoteBolus(amountInUnits: Double, decisionId: UUID?, request: DoseMetadata.RemoteRequest?) async throws
    /// Delivers a bolus for a remote command, rejecting it when the context shows insulin the sender had not seen.
    func deliverRemoteBolus(amountInUnits: Double, decisionId: UUID?, request: DoseMetadata.RemoteRequest?, context: RemoteCommandContext?) async throws
    /// Adds carbs for a remote command, rejecting them when the context shows carb entries the sender had not seen.
    func deliverRemoteCarbs(amountInGrams: Double, absorptionTime: TimeInterval?, foodType: String?, startDate: Date?, context: RemoteCommandContext?) async throws
}

extension RemoteActionDelegate {
    public func deliverRemoteBolus(amountInUnits: Double, decisionId: UUID?, request: DoseMetadata.RemoteRequest?) async throws {
        try await deliverRemoteBolus(amountInUnits: amountInUnits, decisionId: decisionId)
    }

    public func deliverRemoteBolus(amountInUnits: Double, decisionId: UUID?, request: DoseMetadata.RemoteRequest?, context: RemoteCommandContext?) async throws {
        try await deliverRemoteBolus(amountInUnits: amountInUnits, decisionId: decisionId, request: request)
    }

    public func deliverRemoteCarbs(amountInGrams: Double, absorptionTime: TimeInterval?, foodType: String?, startDate: Date?, context: RemoteCommandContext?) async throws {
        try await deliverRemoteCarbs(amountInGrams: amountInGrams, absorptionTime: absorptionTime, foodType: foodType, startDate: startDate)
    }
}

/// An error that ends a remote command with its own reply to the sender.
public protocol RemoteCommandRejection: LocalizedError {
    /// The complete reply to the sender, in English so it reads the same from Loop and Trio
    var replyText: String { get }
}

/// What the sender of a remote command had seen when it sent the command.
public struct RemoteCommandContext: Equatable {
    /// Treatments the sender had seen, from the newest treatment it had fetched
    public struct KnownTreatments: Equatable {
        /// Sync identifiers of treatments the sender had seen
        public var syncIdentifiers: Set<String>
        /// Sync identifiers of all treatments the service has uploaded, seen by the sender or not
        public var uploadedSyncIdentifiers: Set<String>
        /// The service has recorded uploads since this date; treatments created earlier are judged by send time only
        public var recordedSince: Date
        /// Server time of the newest treatment the sender had fetched; edits after it are unknown to the sender
        public var markerDate: Date

        public init(syncIdentifiers: Set<String>, uploadedSyncIdentifiers: Set<String>, recordedSince: Date, markerDate: Date) {
            self.syncIdentifiers = syncIdentifiers
            self.uploadedSyncIdentifiers = uploadedSyncIdentifiers
            self.recordedSince = recordedSince
            self.markerDate = markerDate
        }
    }

    /// When the command was sent, by the sender's clock
    public var sentAt: Date
    /// nil when the service cannot tell which treatments the sender had seen
    public var knownTreatments: KnownTreatments?

    public init(sentAt: Date, knownTreatments: KnownTreatments? = nil) {
        self.sentAt = sentAt
        self.knownTreatments = knownTreatments
    }
}
