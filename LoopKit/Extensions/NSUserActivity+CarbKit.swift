//
//  NSUserActivity+CarbKit.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation


// FIXME: this class should be in Loop now that the carb entry flow is there
/// Conveniences for activity handoff and restoration of creating a carb entry
extension NSUserActivity {
    public static let newCarbEntryActivityType = "NewCarbEntry"

    public static let newCarbEntryUserInfoKey = "NewCarbEntry"
    public static let carbEntryIsMissedMealUserInfoKey = "CarbEntryIsMissedMeal"

    public class func forNewCarbEntry() -> NSUserActivity {
        let activity = NSUserActivity(activityType: newCarbEntryActivityType)
        activity.requiredUserInfoKeys = []
        return activity
    }

    public func update(from entry: NewCarbEntry?, isMissedMeal: Bool = false) {
        if let rawValue = entry?.rawValue {
            addUserInfoEntries(from: [
                NSUserActivity.newCarbEntryUserInfoKey: rawValue,
                NSUserActivity.carbEntryIsMissedMealUserInfoKey: isMissedMeal
            ])
        } else {
            userInfo = nil
        }
    }

    public var newCarbEntry: NewCarbEntry? {
        guard let rawValue = userInfo?[NSUserActivity.newCarbEntryUserInfoKey] as? NewCarbEntry.RawValue else {
            return nil
        }

        return NewCarbEntry(rawValue: rawValue)
    }
    
    public var entryisMissedMeal: Bool {
        guard newCarbEntry != nil else {
            return false
        }
        
        return userInfo?[NSUserActivity.carbEntryIsMissedMealUserInfoKey] as? Bool ?? false
    }
}
