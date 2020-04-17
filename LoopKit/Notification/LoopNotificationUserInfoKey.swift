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
// #if TO BE REMOVED
// Temporary until the rename follows through to Loop
    case alertTypeId
// #endif
    case alertTypeID
    case managerIDForAlert
//    #if TO BE REMOVED
    case cgmAlertID
//    #endif
}
