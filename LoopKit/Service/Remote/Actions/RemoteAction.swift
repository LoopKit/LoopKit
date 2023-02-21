//
//  RemoteAction.swift
//  LoopKit
//
//  Created by Bill Gestrich on 12/25/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation

public enum RemoteAction: Codable {
    case temporaryScheduleOverride(RemoteOverrideAction)
    case cancelTemporaryOverride(RemoteOverrideCancelAction)
    case bolusEntry(RemoteBolusAction)
    case carbsEntry(RemoteCarbAction)
}
