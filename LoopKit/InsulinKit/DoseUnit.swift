//
//  DoseUnit.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 3/28/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation


public enum DoseUnit: String {
    case unitsPerHour = "U/hour"
    case units        = "U"
}

extension DoseUnit: Codable {}
