//
//  Bundle.swift
//  LoopKit
//
//  Created by Cameron Ingham on 11/27/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import Foundation

extension Bundle {
    var localCacheDuration: TimeInterval {
        guard let localCacheDurationDaysString = object(forInfoDictionaryKey: "LoopLocalCacheDurationDays") as? String,
            let localCacheDurationDays = Double(localCacheDurationDaysString) else {
                return 1
        }
        
        return localCacheDurationDays * 60 * 60 * 24
    }
}
