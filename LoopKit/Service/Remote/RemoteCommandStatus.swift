//
//  RemoteCommandStatus.swift
//  LoopKit
//
//  Created by Bill Gestrich on 12/25/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation

public struct RemoteCommandStatus: Codable {
    
    /*
     TODO: Having a message is not ideal. Should reconsider error modeling.
     See comments in RemoteCommandPayload.
     Something similar could be done here.
     The values for success, pending, etc could be the delivery/error dates which we would
     like anyways.
     */
    public let state: RemoteComandState
    public let message: String
    
    public enum RemoteComandState: String, Codable {
        case Pending
        case InProgress
        case Success
        case Error
        
        var title: String {
            switch self {
            case .Pending:
                return "Pending"
            case .InProgress:
                return "In-Progress"
            case .Success:
                return "Success"
            case .Error:
                return "Error"
            }
        }
    }
    
    public enum RemoteCommandStatusError: LocalizedError {
        case parseError
    }
    
    //TODO: Add delivery date
    public init(state: RemoteCommandStatus.RemoteComandState, message: String) {
        self.state = state
        self.message = message
    }
    
}
