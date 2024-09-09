//
//  BluetoothServices.swift
//  MockKit
//
//  Created by Pete Schwamb on 4/3/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import CoreBluetooth

protocol CBUUIDRawValue: RawRepresentable {}
extension CBUUIDRawValue where RawValue == String {
    var cbUUID: CBUUID {
        return CBUUID(string: rawValue)
    }
}

enum HeartbeatFobUUID: String, CBUUIDRawValue {
    case heartbeatService = "02351400-99C5-4197-B856-69219C030201"
    case batteryService = "180F"
}

enum BatteryServiceCharacteristicUUID: String, CBUUIDRawValue {
    // Read
    case batteryLevel = "2A19"
}


enum HeartbeatServiceCharacteristicUUID: String, CBUUIDRawValue {

    // Read/Notify
    case value = "02351401-99C5-4197-B856-69219C030201"

    // Read/Write
    case config = "F8083534-849E-531C-C594-30F1F86A4EA5"
}

extension PeripheralManager.Configuration {
    static var heartbeatFob: PeripheralManager.Configuration {
        return PeripheralManager.Configuration(
            serviceCharacteristics: [
                HeartbeatFobUUID.heartbeatService.cbUUID: [
                    HeartbeatServiceCharacteristicUUID.value.cbUUID,
                    HeartbeatServiceCharacteristicUUID.config.cbUUID
                ],
                HeartbeatFobUUID.batteryService.cbUUID: [
                    BatteryServiceCharacteristicUUID.batteryLevel.cbUUID
                ]
            ],
            notifyingCharacteristics: [
                HeartbeatFobUUID.heartbeatService.cbUUID: [
                    HeartbeatServiceCharacteristicUUID.value.cbUUID
                ]
            ],
            valueUpdateMacros: [:]
        )
    }
}
