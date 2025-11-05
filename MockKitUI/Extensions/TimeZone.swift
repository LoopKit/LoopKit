//
//  TimeZone.swift
//  LoopKit
//
//  Created by Nathaniel Hamming on 2025-11-05.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import Foundation

extension TimeZone {
    static var currentFixed: TimeZone {
        TimeZone(secondsFromGMT: TimeZone.current.secondsFromGMT())!
    }
}
