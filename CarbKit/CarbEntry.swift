//
//  CarbEntry.swift
//  CarbKit
//
//  Created by Nathan Racklyeft on 1/3/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import LoopKit


public protocol CarbEntry: SampleValue {
    var foodType: String? { get }
    var absorptionTime: TimeInterval? { get }
    var createdByCurrentApp: Bool { get }
    var isUploaded: Bool { get }
    var externalId: String? { get }
}
