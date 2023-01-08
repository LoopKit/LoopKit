//
//  RemoteCommand.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 12/25/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

public protocol RemoteCommand {
    
    var id: String {get}
    var action: RemoteAction {get}
    var status: RemoteCommandStatus {get}
    //TODO: Add creation date
    
    /*
     TODO: Should we support "future" commands?
     TODO: Should the expiration date be in here?
     TODO: Should creationDate be in here?
     */
    
    func checkValidity() throws
    
    func markInProgress() async throws
    func markError(_ error: Error) async throws
    func markSuccess() async throws
}
