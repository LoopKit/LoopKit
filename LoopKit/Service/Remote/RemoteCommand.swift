//
//  RemoteCommand.swift
//  LoopKit
//
//  Created by Bill Gestrich on 2/25/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

public protocol RemoteCommand {
    var id: String {get}
    var action: Action {get}
    func validate() throws
}
