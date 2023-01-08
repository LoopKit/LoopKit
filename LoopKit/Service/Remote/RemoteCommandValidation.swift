//
//  RemoteCommandValidation.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 12/25/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation

public protocol RemoteCommandValidation {
    func checkValidity() throws
}
