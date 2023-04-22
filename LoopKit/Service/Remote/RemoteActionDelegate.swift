//
//  RemoteActionDelegate.swift
//  LoopKit
//
//  Created by Bill Gestrich on 3/19/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation

public protocol RemoteActionDelegate: AnyObject {
    func handleRemoteOverride(name: String, durationTime: TimeInterval?, remoteAddress: String) async throws
    func handleRemoteOverrideCancel() async throws
    func handleRemoteCarb(amountInGrams: Double, absorptionTime: TimeInterval?, foodType: String?, startDate: Date?) async throws
    func handleRemoteBolus(amountInUnits: Double) async throws
    func handleRemoteClosedLoop(activate: Bool) async throws
    func handleRemoteAutobolus(activate: Bool) async throws
}
