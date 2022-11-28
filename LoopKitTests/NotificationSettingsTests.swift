//
//  NotificationSettingsTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 9/17/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import Foundation
import LoopKit

class NotificationSettingsCodableTests: XCTestCase {
    func testCodable() throws {
        try assertNotificationSettingsCodable(NotificationSettings.test, encodesJSON: """
{
  "alertSetting" : "disabled",
  "alertStyle" : "banner",
  "announcementSetting" : "enabled",
  "authorizationStatus" : "authorized",
  "badgeSetting" : "enabled",
  "carPlaySetting" : "notSupported",
  "criticalAlertSetting" : "enabled",
  "lockScreenSetting" : "disabled",
  "notificationCenterSetting" : "notSupported",
  "providesAppNotificationSettings" : true,
  "scheduledDeliverySetting" : "disabled",
  "showPreviewsSetting" : "whenAuthenticated",
  "soundSetting" : "enabled",
  "temporaryMuteAlertsSetting" : {
    "enabled" : {
      "_0" : 1800
    }
  },
  "timeSensitiveSetting" : "enabled"
}
"""
        )
    }

    func testMigration() throws {
        let oldSettingsString = """
{
  "alertSetting" : "disabled",
  "alertStyle" : "banner",
  "announcementSetting" : "enabled",
  "authorizationStatus" : "authorized",
  "badgeSetting" : "enabled",
  "carPlaySetting" : "notSupported",
  "criticalAlertSetting" : "enabled",
  "lockScreenSetting" : "disabled",
  "notificationCenterSetting" : "notSupported",
  "providesAppNotificationSettings" : true,
  "showPreviewsSetting" : "whenAuthenticated",
  "soundSetting" : "enabled"
}
"""
        let _ = try decoder.decode(NotificationSettings.self, from: oldSettingsString.data(using: .utf8)!)
    }
    
    private func assertNotificationSettingsCodable(_ original: NotificationSettings, encodesJSON string: String) throws {
        let data = try encoder.encode(original)
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
        let decoded = try decoder.decode(NotificationSettings.self, from: data)
        XCTAssertEqual(decoded, original)
    }
    
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

fileprivate extension NotificationSettings {
    static var test: NotificationSettings {
        return NotificationSettings(authorizationStatus: .authorized,
                                    soundSetting: .enabled,
                                    badgeSetting: .enabled,
                                    alertSetting: .disabled,
                                    notificationCenterSetting: .notSupported,
                                    lockScreenSetting: .disabled,
                                    carPlaySetting: .notSupported,
                                    alertStyle: .banner,
                                    showPreviewsSetting: .whenAuthenticated,
                                    criticalAlertSetting: .enabled,
                                    providesAppNotificationSettings: true,
                                    announcementSetting: .enabled,
                                    timeSensitiveSetting: .enabled,
                                    scheduledDeliverySetting: .disabled,
                                    temporaryMuteAlertsSetting: .enabled(.minutes(30)))
    }
}
