//
//  NSUserDefaults.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 2/20/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation


extension NSUserDefaults {
    private enum Key: String {
        case CarbEntryCache = "com.loudnate.CarbKit.CarbEntryCache"
    }

    var carbEntryCache: [StoredCarbEntry]? {
        get {
            if let rawValue = arrayForKey(Key.CarbEntryCache.rawValue) as? [StoredCarbEntry.RawValue] {
                return rawValue.flatMap { StoredCarbEntry(rawValue: $0) }
            } else {
                return nil
            }
        }
        set {
            setObject(newValue?.map { $0.rawValue }, forKey: Key.CarbEntryCache.rawValue)
        }
    }
}