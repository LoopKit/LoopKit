//
//  DeletedCarbEntry.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation


public struct DeletedCarbEntry {
    public let externalID: String?
    public var isUploaded: Bool
    public let uuid: UUID?
    public let syncIdentifier: String?
    public let syncVersion: Int

    public init(externalID: String?, isUploaded: Bool, uuid: UUID?, syncIdentifier: String?, syncVersion: Int) {
        self.externalID = externalID
        self.isUploaded = isUploaded
        self.uuid = uuid
        self.syncIdentifier = syncIdentifier
        self.syncVersion = syncVersion
    }
}

extension DeletedCarbEntry {
    init(managedObject: DeletedCarbObject) {
        self.init(
            externalID: managedObject.externalID,
            isUploaded: managedObject.uploadState == .uploaded,
            uuid: managedObject.uuid,
            syncIdentifier: managedObject.syncIdentifier,
            syncVersion: Int(managedObject.syncVersion)
        )
    }
}
