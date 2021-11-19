//
//  CodableDevice.swift
//  LoopKit
//
//  Created by Darin Krauss on 10/11/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import HealthKit

struct CodableDevice: Codable {
    let name: String?
    let manufacturer: String?
    let model: String?
    let hardwareVersion: String?
    let firmwareVersion: String?
    let softwareVersion: String?
    let localIdentifier: String?
    let udiDeviceIdentifier: String?

    init(_ device: HKDevice) {
        self.name = device.name
        self.manufacturer = device.manufacturer
        self.model = device.model
        self.hardwareVersion = device.hardwareVersion
        self.firmwareVersion = device.firmwareVersion
        self.softwareVersion = device.softwareVersion
        self.localIdentifier = device.localIdentifier
        self.udiDeviceIdentifier = device.udiDeviceIdentifier
    }

    var device: HKDevice {
        return HKDevice(name: name,
                        manufacturer: manufacturer,
                        model: model,
                        hardwareVersion: hardwareVersion,
                        firmwareVersion: firmwareVersion,
                        softwareVersion: softwareVersion,
                        localIdentifier: localIdentifier,
                        udiDeviceIdentifier: udiDeviceIdentifier)
    }
}

