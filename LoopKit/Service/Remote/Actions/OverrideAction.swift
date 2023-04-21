//
//  OverrideAction.swift
//  LoopKit
//
//  Created by Bill Gestrich on 12/25/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation

public struct OverrideAction: Codable {
    
    public let name: String
    public let durationTime: TimeInterval?
    public let remoteAddress: String
    
    public init(name: String, durationTime: TimeInterval? = nil, remoteAddress: String) {
        self.name = name
        self.durationTime = durationTime
        self.remoteAddress = remoteAddress
    }
    
}
