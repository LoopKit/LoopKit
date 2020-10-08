//
//  PumpEvent+CoreDataProperties.swift
//  LoopKit
//
//  Created by Nate Racklyeft on 8/1/16.
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import Foundation
import CoreData


extension PumpEvent {

    @nonobjc class func fetchRequest() -> NSFetchRequest<PumpEvent> {
        return NSFetchRequest<PumpEvent>(entityName: "PumpEvent")
    }

    @NSManaged var createdAt: Date!
    @NSManaged var date: Date!
    @NSManaged var primitiveDoseType: String?
    @NSManaged var primitiveDuration: NSNumber?
    @NSManaged var primitiveType: String?
    @NSManaged var primitiveUnit: String?
    @NSManaged var primitiveUploaded: NSNumber?
    @NSManaged var primitiveValue: NSNumber?
    @NSManaged var primitiveDeliveredUnits: NSNumber?
    @NSManaged var mutable: Bool
    @NSManaged var raw: Data?
    @NSManaged var title: String?
    @NSManaged var modificationCounter: Int64

}

extension PumpEvent: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(doseType?.rawValue, forKey: .doseType)
        try container.encode(duration, forKey: .duration)
        try container.encodeIfPresent(type?.rawValue, forKey: .type)
        try container.encodeIfPresent(unit?.rawValue, forKey: .unit)
        try container.encode(uploaded, forKey: .uploaded)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encodeIfPresent(deliveredUnits, forKey: .deliveredUnits)
        try container.encode(mutable, forKey: .mutable)
        try container.encodeIfPresent(raw?.base64EncodedString(), forKey: .raw)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encode(modificationCounter, forKey: .modificationCounter)
    }

    private enum CodingKeys: String, CodingKey {
        case createdAt
        case date
        case doseType
        case duration
        case type
        case unit
        case uploaded
        case value
        case deliveredUnits
        case mutable
        case raw
        case title
        case modificationCounter
    }
}
