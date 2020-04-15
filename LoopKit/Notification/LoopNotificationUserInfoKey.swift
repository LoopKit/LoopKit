//
//  LoopNotificationUserInfoKey.swift
//  LoopKit
//
//  Created by Nathaniel Hamming on 2019-10-16.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

public enum LoopNotificationUserInfoKey: String {
    case bolusAmount
    case bolusStartDate
    case alertTypeId
    case managerIDForAlert
    #if !USE_NEW_ALERT_FACILITY
    case cgmAlertID
    #endif
}
