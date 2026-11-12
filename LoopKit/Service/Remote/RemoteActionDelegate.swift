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

    /// Activates the profile named `name` when it matches `expectedFingerprint`.
    func switchRemoteTherapyProfile(name: String, expectedFingerprint: String) async throws
    /// Creates `profile` when `originalName` is nil, else updates that profile; with an `expectedFingerprint` the original must match it.
    func saveRemoteTherapyProfile(_ profile: TherapyProfile, originalName: String?, expectedFingerprint: String?) async throws
    /// Deletes the profile named `name` when it matches `expectedFingerprint`.
    func deleteRemoteTherapyProfile(name: String, expectedFingerprint: String) async throws
    /// Replaces the scheduled profile switches when the current list matches `expectedFingerprint`.
    func saveRemoteScheduledProfileSwitches(_ entries: [ScheduledProfileSwitch], expectedFingerprint: String) async throws
}
