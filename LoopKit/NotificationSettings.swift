//
//  NotificationSettings.swift
//  LoopKit
//
//  Created by Darin Krauss on 9/17/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import UserNotifications

public struct NotificationSettings: Equatable {
    public enum AuthorizationStatus: String, Codable {
        case notDetermined
        case denied
        case authorized
        case provisional
        case ephemeral
        case unknown

        public init(_ authorizationStatus: UNAuthorizationStatus) {
            switch authorizationStatus {
            case .notDetermined:
                self = .notDetermined
            case .denied:
                self = .denied
            case .authorized:
                self = .authorized
            case .provisional:
                self = .provisional
            case .ephemeral:
                self = .ephemeral
            @unknown default:
                self = .unknown
            }
        }
    }

    public enum NotificationSetting: String, Codable {
        case notSupported
        case disabled
        case enabled
        case unknown

        public init(_ notificationSetting: UNNotificationSetting) {
            switch notificationSetting {
            case .notSupported:
                self = .notSupported
            case .disabled:
                self = .disabled
            case .enabled:
                self = .enabled
            @unknown default:
                self = .unknown
            }
        }
    }

    public enum AlertStyle: String, Codable {
        case none
        case banner
        case alert
        case unknown

        public init(_ alertStyle: UNAlertStyle) {
            switch alertStyle {
            case .none:
                self = .none
            case .banner:
                self = .banner
            case .alert:
                self = .alert
            @unknown default:
                self = .unknown
            }
        }
    }

    public enum ShowPreviewsSetting: String, Codable {
        case always
        case whenAuthenticated
        case never
        case unknown

        public init(_ showPreviewsSetting: UNShowPreviewsSetting) {
            switch showPreviewsSetting {
            case .always:
                self = .always
            case .whenAuthenticated:
                self = .whenAuthenticated
            case .never:
                self = .never
            @unknown default:
                self = .unknown
            }
        }
    }

    public let authorizationStatus: AuthorizationStatus
    public let soundSetting: NotificationSetting
    public let badgeSetting: NotificationSetting
    public let alertSetting: NotificationSetting
    public let notificationCenterSetting: NotificationSetting
    public let lockScreenSetting: NotificationSetting
    public let carPlaySetting: NotificationSetting
    public let alertStyle: AlertStyle
    public let showPreviewsSetting: ShowPreviewsSetting
    public let criticalAlertSetting: NotificationSetting
    public let providesAppNotificationSettings: Bool
    public let announcementSetting: NotificationSetting
    public let timeSensitiveSetting: NotificationSetting
    public let scheduledDeliverySetting: NotificationSetting

    public init(authorizationStatus: AuthorizationStatus,
                soundSetting: NotificationSetting,
                badgeSetting: NotificationSetting,
                alertSetting: NotificationSetting,
                notificationCenterSetting: NotificationSetting,
                lockScreenSetting: NotificationSetting,
                carPlaySetting: NotificationSetting,
                alertStyle: AlertStyle,
                showPreviewsSetting: ShowPreviewsSetting,
                criticalAlertSetting: NotificationSetting,
                providesAppNotificationSettings: Bool,
                announcementSetting: NotificationSetting,
                timeSensitiveSetting: NotificationSetting,
                scheduledDeliverySetting: NotificationSetting)
    {
        self.authorizationStatus = authorizationStatus
        self.soundSetting = soundSetting
        self.badgeSetting = badgeSetting
        self.alertSetting = alertSetting
        self.notificationCenterSetting = notificationCenterSetting
        self.lockScreenSetting = lockScreenSetting
        self.carPlaySetting = carPlaySetting
        self.alertStyle = alertStyle
        self.showPreviewsSetting = showPreviewsSetting
        self.criticalAlertSetting = criticalAlertSetting
        self.providesAppNotificationSettings = providesAppNotificationSettings
        self.announcementSetting = announcementSetting
        self.timeSensitiveSetting = timeSensitiveSetting
        self.scheduledDeliverySetting = scheduledDeliverySetting
    }
}


extension NotificationSettings: Codable {

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            authorizationStatus: try container.decode(AuthorizationStatus.self, forKey: .authorizationStatus),
            soundSetting: try container.decode(NotificationSetting.self, forKey: .soundSetting),
            badgeSetting: try container.decode(NotificationSetting.self, forKey: .badgeSetting),
            alertSetting: try container.decode(NotificationSetting.self, forKey: .alertSetting),
            notificationCenterSetting: try container.decode(NotificationSetting.self, forKey: .notificationCenterSetting),
            lockScreenSetting: try container.decode(NotificationSetting.self, forKey: .lockScreenSetting),
            carPlaySetting: try container.decode(NotificationSetting.self, forKey: .carPlaySetting),
            alertStyle: try container.decode(AlertStyle.self, forKey: .alertStyle),
            showPreviewsSetting: try container.decode(ShowPreviewsSetting.self, forKey: .showPreviewsSetting),
            criticalAlertSetting: try container.decode(NotificationSetting.self, forKey: .criticalAlertSetting),
            providesAppNotificationSettings: try container.decode(Bool.self, forKey: .providesAppNotificationSettings),
            announcementSetting: try container.decode(NotificationSetting.self, forKey: .announcementSetting),
            timeSensitiveSetting: try container.decodeIfPresent(NotificationSetting.self, forKey: .timeSensitiveSetting) ?? .unknown,
            scheduledDeliverySetting: try container.decodeIfPresent(NotificationSetting.self, forKey: .scheduledDeliverySetting) ?? .unknown)
    }

//    public func encode(to encoder: Encoder) throws {
//        let bloodGlucoseUnit = self.bloodGlucoseUnit ?? StoredSettings.codingGlucoseUnit
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encode(date, forKey: .date)
//        try container.encode(controllerTimeZone, forKey: .controllerTimeZone)
//        try container.encode(dosingEnabled, forKey: .dosingEnabled)
//        try container.encodeIfPresent(glucoseTargetRangeSchedule, forKey: .glucoseTargetRangeSchedule)
//        try container.encodeIfPresent(preMealTargetRange?.doubleRange(for: bloodGlucoseUnit), forKey: .preMealTargetRange)
//        try container.encodeIfPresent(workoutTargetRange?.doubleRange(for: bloodGlucoseUnit), forKey: .workoutTargetRange)
//        try container.encodeIfPresent(overridePresets, forKey: .overridePresets)
//        try container.encodeIfPresent(scheduleOverride, forKey: .scheduleOverride)
//        try container.encodeIfPresent(preMealOverride, forKey: .preMealOverride)
//        try container.encodeIfPresent(maximumBasalRatePerHour, forKey: .maximumBasalRatePerHour)
//        try container.encodeIfPresent(maximumBolus, forKey: .maximumBolus)
//        try container.encodeIfPresent(suspendThreshold, forKey: .suspendThreshold)
//        try container.encodeIfPresent(insulinType, forKey: .insulinType)
//        try container.encodeIfPresent(deviceToken, forKey: .deviceToken)
//        try container.encodeIfPresent(defaultRapidActingModel, forKey: .defaultRapidActingModel)
//        try container.encodeIfPresent(basalRateSchedule, forKey: .basalRateSchedule)
//        try container.encodeIfPresent(insulinSensitivitySchedule, forKey: .insulinSensitivitySchedule)
//        try container.encodeIfPresent(carbRatioSchedule, forKey: .carbRatioSchedule)
//        try container.encodeIfPresent(notificationSettings, forKey: .notificationSettings)
//        try container.encodeIfPresent(controllerDevice, forKey: .controllerDevice)
//        try container.encodeIfPresent(cgmDevice.map { CodableDevice($0) }, forKey: .cgmDevice)
//        try container.encodeIfPresent(pumpDevice.map { CodableDevice($0) }, forKey: .pumpDevice)
//        try container.encode(bloodGlucoseUnit.unitString, forKey: .bloodGlucoseUnit)
//        try container.encode(automaticDosingStrategy, forKey: .automaticDosingStrategy)
//        try container.encode(syncIdentifier, forKey: .syncIdentifier)
//    }

    private enum CodingKeys: String, CodingKey {

        case authorizationStatus
        case soundSetting
        case badgeSetting
        case alertSetting
        case notificationCenterSetting
        case lockScreenSetting
        case carPlaySetting
        case alertStyle
        case showPreviewsSetting
        case criticalAlertSetting
        case providesAppNotificationSettings
        case announcementSetting
        case timeSensitiveSetting
        case scheduledDeliverySetting
    }
}
