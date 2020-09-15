//
//  SettingsObject+CoreDataProperties.swift
//  LoopKit
//
//  Created by Darin Krauss on 4/30/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import CoreData

extension SettingsObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SettingsObject> {
        return NSFetchRequest<SettingsObject>(entityName: "SettingsObject")
    }

    @NSManaged public var data: Data
    @NSManaged public var date: Date
    @NSManaged public var modificationCounter: Int64
}
