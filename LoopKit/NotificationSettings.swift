//
//  NotificationSettings.swift
//  LoopKit
//
//  Created by Darin Krauss on 9/17/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import UserNotifications

public struct NotificationSettings: Codable, Equatable {
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
                announcementSetting: NotificationSetting) {
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
    }
}

