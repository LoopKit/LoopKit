//
//  DeletedCarbEntry.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation


public struct DeletedCarbEntry {
    public let externalID: String
    public var isUploaded: Bool

    public init(externalID: String, isUploaded: Bool) {
        self.externalID = externalID
        self.isUploaded = isUploaded
    }
}


extension DeletedCarbEntry {
    init(managedObject: DeletedCarbObject) {
        self.init(
            externalID: managedObject.externalID!,
            isUploaded: managedObject.uploadState == .uploaded
        )
    }
}
