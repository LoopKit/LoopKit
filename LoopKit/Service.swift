//
//  Service.swift
//  LoopKit
//
//  Created by Darin Krauss on 5/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

public protocol Service: AnyObject {

    typealias RawStateValue = [String: Any]

    /// The unique identifier of this type of service.
    static var serviceIdentifier: String { get }

    /// The localized title of this type of service.
    static var localizedTitle: String { get }

    /// Initializes the service with the previously-serialized state.
    ///
    /// - Parameters:
    ///     - rawState: The previously-serialized state of the service.
    init?(rawState: RawStateValue)

    /// The current, serializable state of the service.
    var rawState: RawStateValue { get }

}

public extension Service {

    var serviceIdentifier: String { return type(of: self).serviceIdentifier }

    var localizedTitle: String { return type(of: self).localizedTitle }

}
