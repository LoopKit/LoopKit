//
//  NSUserDefaults.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 2/20/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation


extension UserDefaults {
    private enum Key: String {
        case CarbEntryCache = "com.loudnate.CarbKit.CarbEntryCache"
        case ModifiedCarbEntries = "com.loudnate.CarbKit.ModifiedCarbEntries"
        case DeletedCarbEntryIds = "com.loudnate.CarbKit.DeletedCarbEntryIds"
    }

    func purgeLegacyCarbEntryKeys() {
        removeObject(forKey: Key.CarbEntryCache.rawValue)
        removeObject(forKey: Key.ModifiedCarbEntries.rawValue)
        removeObject(forKey: Key.DeletedCarbEntryIds.rawValue)
    }

    var modifiedCarbEntries: [StoredCarbEntry]? {
        get {
            if let rawValue = array(forKey: Key.ModifiedCarbEntries.rawValue) as? [StoredCarbEntry.RawValue] {
                return rawValue.compactMap { StoredCarbEntry(rawValue: $0) }
            } else {
                return nil
            }
        }
    }

    var deletedCarbEntryIds: [String]? {
        get {
            return array(forKey: Key.DeletedCarbEntryIds.rawValue) as? [String]
        }
    }
}
