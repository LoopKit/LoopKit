//
//  NSUserActivity+CarbKit.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation


/// Conveniences for activity handoff and restoration of creating a carb entry
extension NSUserActivity {
    public static let newCarbEntryActivityType = "NewCarbEntry"

    public static let newCarbEntryUserInfoKey = "NewCarbEntry"
    public static let carbEntryIsUAMUserInfoKey = "CarbEntryIsUAM"

    public class func forNewCarbEntry() -> NSUserActivity {
        let activity = NSUserActivity(activityType: newCarbEntryActivityType)
        activity.requiredUserInfoKeys = []
        return activity
    }

    public func update(from entry: NewCarbEntry?, isUnannouncedMeal: Bool = false) {
        if let rawValue = entry?.rawValue {
            addUserInfoEntries(from: [
                NSUserActivity.newCarbEntryUserInfoKey: rawValue,
                NSUserActivity.carbEntryIsUAMUserInfoKey: isUnannouncedMeal
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
    
    public var entryIsUnannouncedMeal: Bool {
        guard newCarbEntry != nil else {
            return false
        }
        
        return userInfo?[NSUserActivity.carbEntryIsUAMUserInfoKey] as? Bool ?? false
    }
}
