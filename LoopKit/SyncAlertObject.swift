//
//  SyncAlertObject.swift
//  LoopKit
//
//  Created by Darin Krauss on 1/19/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation

public struct SyncAlertObject: Codable {
    public let identifier: Alert.Identifier
    public let trigger: Alert.Trigger
    public let interruptionLevel: Alert.InterruptionLevel
    public let foregroundContent: Alert.Content?
    public let backgroundContent: Alert.Content?
    public let sound: Alert.Sound?
    public let metadata: Alert.Metadata?
    public let issuedDate: Date
    public let acknowledgedDate: Date?
    public let retractedDate: Date?
    public let syncIdentifier: UUID

    public init(identifier: Alert.Identifier,
                trigger: Alert.Trigger,
                interruptionLevel: Alert.InterruptionLevel,
                foregroundContent: Alert.Content?,
                backgroundContent: Alert.Content?,
                sound: Alert.Sound?,
                metadata: Alert.Metadata?,
                issuedDate: Date,
                acknowledgedDate: Date?,
                retractedDate: Date?,
                syncIdentifier: UUID) {
        self.identifier = identifier
        self.trigger = trigger
        self.interruptionLevel = interruptionLevel
        self.foregroundContent = foregroundContent
        self.backgroundContent = backgroundContent
        self.sound = sound
        self.metadata = metadata
        self.issuedDate = issuedDate
        self.acknowledgedDate = acknowledgedDate
        self.retractedDate = retractedDate
        self.syncIdentifier = syncIdentifier
    }
}
