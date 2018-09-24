//
//  ServiceAuthentication.swift
//  Loop
//
//  Created by Nate Racklyeft on 7/2/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//


// Defines the authentication for a service
public protocol ServiceAuthentication: class {
    // The title of the service
    var title: String { get }

    // The indexed credentials (e.g. username, password) used to authenticate
    var credentialValues: [String?] { get set }

    // Whether the current credential values are valid authorization
    var isAuthorized: Bool { get set }

    // Tests the credentials for valid authorization
    func verify(_ completion: @escaping (_ success: Bool, _ error: Error?) -> Void)

    // Clears the credential values and authorization status
    func reset()
}
