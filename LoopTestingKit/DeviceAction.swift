//
//  DeviceAction.swift
//  LoopTestingKit
//
//  Created by Nathaniel Hamming on 2023-04-19.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation

public struct DeviceAction: Equatable, Codable {
    public let managerIdentifier: String
    public let details: String
}
