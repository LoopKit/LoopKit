//
//  ServiceAuthenticationUI.swift
//  LoopKitUI
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import LoopKit


public protocol ServiceAuthenticationUI: ServiceAuthentication {
    // The indexed credentials (e.g. username, password) used to authenticate
    var credentialFormFields: [ServiceCredential] { get }
}


public extension ServiceAuthenticationUI {
    var credentials: [(field: ServiceCredential, value: String?)] {
        return zip(credentialFormFields, credentialValues).map { (field, value) in
            return (field: field, value: value)
        }
    }

    func resetCredentials() {
        for (index, field) in credentialFormFields.enumerated() {
            credentialValues[index] = field.options?.first?.value
        }

        reset()
    }
}

