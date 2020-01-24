//
//  DeviceLogEntryType.swift
//  LoopKit
//
//  Created by Pete Schwamb on 1/13/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

public enum DeviceLogEntryType: String {
    case send
    case receive
    case error
    case delegate
    case delegateResponse
}
