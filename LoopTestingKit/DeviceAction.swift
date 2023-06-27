//
//  DeviceAction.swift
//  LoopTestingKit
//
//  Created by Nathaniel Hamming on 2023-04-19.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation

public struct DeviceAction: Equatable, Codable, RawRepresentable {
    public typealias RawValue = [String: Any]
    
    public let managerIdentifier: String
    public let details: String
    
    public init?(rawValue: [String : Any]) {
        guard let managerIdentifier = rawValue["managerIdentifier"] as? String, let details = rawValue["details"] as? String else {
            return nil
        }
        
        self.managerIdentifier = managerIdentifier
        self.details = details
    }
    
    public var rawValue: [String : Any] {
        [
            "managerIdentifier": managerIdentifier,
            "details": details
        ]
    }
}
