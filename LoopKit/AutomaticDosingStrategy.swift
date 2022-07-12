//
//  DosingStrategy.swift
//  LoopKit
//
//  Created by Pete Schwamb on 6/27/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation


public enum AutomaticDosingStrategy: Int, CaseIterable, Codable {
    case tempBasalOnly
    case automaticBolus
}
