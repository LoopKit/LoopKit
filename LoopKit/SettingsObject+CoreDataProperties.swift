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

extension SettingsObject: Encodable {
    func encode(to encoder: Encoder) throws {
        try EncodableSettingsObject(self).encode(to: encoder)
    }
}

fileprivate struct EncodableSettingsObject: Encodable {
    var data: StoredSettings
    var date: Date
    var modificationCounter: Int64

    init(_ object: SettingsObject) throws {
        self.data = try PropertyListDecoder().decode(StoredSettings.self, from: object.data)
        self.date = object.date
        self.modificationCounter = object.modificationCounter
    }
}
