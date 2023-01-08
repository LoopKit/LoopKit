//
//  RemoteClosedLoopAction.swift
//  LoopKit
//
//  Created by Bill Gestrich on 1/8/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation

public struct RemoteClosedLoopAction: Codable {
    
    public let active: Bool
    
    public init(active: Bool) {
        self.active = active
    }
}
