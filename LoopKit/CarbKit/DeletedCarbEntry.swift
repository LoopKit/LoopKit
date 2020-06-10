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
    public let startDate: Date?
    public let uuid: UUID?
    public let syncIdentifier: String?
    public let syncVersion: Int

    public init(externalID: String?, isUploaded: Bool, startDate: Date?, uuid: UUID?, syncIdentifier: String?, syncVersion: Int) {
        self.externalID = externalID
        self.isUploaded = isUploaded
        self.startDate = startDate
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
            startDate: managedObject.startDate,
            uuid: managedObject.uuid,
            syncIdentifier: managedObject.syncIdentifier,
            syncVersion: Int(managedObject.syncVersion)
        )
    }
}
