//
//  DosingStrategy.swift
//  LoopKit
//
//  Created by Pete Schwamb on 6/27/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation


public enum AutomaticDosingStrategy: Int, CaseIterable, Codable {
    // Raw values are pinned so persisted settings keep their meaning across reorderings.
    // Source order drives `allCases`, which the Dosing Strategy picker iterates.
    case automaticBolus = 1
    case tempBasalOnly = 0
}
