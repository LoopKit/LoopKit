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
}

extension RemoteActionDelegate {
    public func deliverRemoteBolus(amountInUnits: Double, decisionId: UUID?, request: DoseMetadata.RemoteRequest?) async throws {
        try await deliverRemoteBolus(amountInUnits: amountInUnits, decisionId: decisionId)
    }
}
