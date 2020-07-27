//
//  SupportedInsulinModelSettings.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 7/20/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

public struct SupportedInsulinModelSettings {
    public let fiaspModelEnabled: Bool
    public let walshModelEnabled: Bool
    public init(fiaspModelEnabled: Bool, walshModelEnabled: Bool) {
        self.fiaspModelEnabled = fiaspModelEnabled
        self.walshModelEnabled = walshModelEnabled
    }
}
