//
//  HKDevice+Encodable.swift
//  LoopKit
//
//  Created by Rick Pasetto on 8/2/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

extension HKDevice: Encodable {
    private enum CodingKeys: String, CodingKey {
       case name, manufacturer, model, hardwareVersion, firmwareVersion, softwareVersion, localIdentifier, udiDeviceIdentifier
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(manufacturer, forKey: .manufacturer)
        try container.encodeIfPresent(model, forKey: .model)
        try container.encodeIfPresent(hardwareVersion, forKey: .hardwareVersion)
        try container.encodeIfPresent(firmwareVersion, forKey: .firmwareVersion)
        try container.encodeIfPresent(softwareVersion, forKey: .softwareVersion)
        try container.encodeIfPresent(localIdentifier, forKey: .localIdentifier)
        try container.encodeIfPresent(udiDeviceIdentifier, forKey: .udiDeviceIdentifier)
    }
        
    // Swift won't let us implement Decodable for HKDevice, but we can at least implement deserialization "by hand"
    // by trying both Plist and JSON -- not very efficient, but gets the job done.
    public convenience init(from data: Data) throws {
        var props = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        if props == nil {
            props = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        }
        guard let props = props else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Invalid data"))
        }
        self.init(from: props)
    }

    convenience init(from props: [String: Any]) {
        self.init(name: props[CodingKeys.name.rawValue] as! String?,
                  manufacturer: props[CodingKeys.manufacturer.rawValue] as! String?,
                  model: props[CodingKeys.model.rawValue] as! String?,
                  hardwareVersion: props[CodingKeys.hardwareVersion.rawValue] as! String?,
                  firmwareVersion: props[CodingKeys.firmwareVersion.rawValue] as! String?,
                  softwareVersion: props[CodingKeys.softwareVersion.rawValue] as! String?,
                  localIdentifier: props[CodingKeys.localIdentifier.rawValue] as! String?,
                  udiDeviceIdentifier: props[CodingKeys.udiDeviceIdentifier.rawValue] as! String?)
    }

}


