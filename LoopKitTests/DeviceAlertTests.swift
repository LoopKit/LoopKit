//
//  DeviceAlertTests.swift
//  LoopKitTests
//
//  Created by Rick Pasetto on 5/1/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit

class DeviceAlertTests: XCTestCase {
    let identifier = DeviceAlert.Identifier(managerIdentifier: "managerIdentifier1", alertIdentifier: "alertIdentifier1")
    let foregroundContent = DeviceAlert.Content(title: "title1", body: "body1", acknowledgeActionButtonLabel: "acknowledgeActionButtonLabel1", isCritical: false)
    let backgroundContent = DeviceAlert.Content(title: "title2", body: "body2", acknowledgeActionButtonLabel: "acknowledgeActionButtonLabel2", isCritical: false)

    func testIdentifierValue() {
        XCTAssertEqual("managerIdentifier1.alertIdentifier1", identifier.value)
    }
    
    func testDeviceAlertImmediateEncodable() {
        let alert = DeviceAlert(identifier: identifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .immediate)
        let str = try? alert.encodeToString()
    XCTAssertEqual("{\"trigger\":\"immediate\",\"identifier\":{\"managerIdentifier\":\"managerIdentifier1\",\"alertIdentifier\":\"alertIdentifier1\"},\"foregroundContent\":{\"body\":\"body1\",\"isCritical\":false,\"title\":\"title1\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel1\"},\"backgroundContent\":{\"body\":\"body2\",\"isCritical\":false,\"title\":\"title2\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel2\"}}", str)
    }
    
    func testDeviceAlertDelayedEncodable() {
        let alert = DeviceAlert(identifier: identifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .delayed(interval: 1.0))
        let str = try? alert.encodeToString()
    XCTAssertEqual("{\"trigger\":{\"delayed\":{\"delayInterval\":1}},\"identifier\":{\"managerIdentifier\":\"managerIdentifier1\",\"alertIdentifier\":\"alertIdentifier1\"},\"foregroundContent\":{\"body\":\"body1\",\"isCritical\":false,\"title\":\"title1\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel1\"},\"backgroundContent\":{\"body\":\"body2\",\"isCritical\":false,\"title\":\"title2\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel2\"}}", str)
    }
    
    func testDeviceAlertRepeatingEncodable() {
        let alert = DeviceAlert(identifier: identifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .repeating(repeatInterval: 2.0))
        let str = try? alert.encodeToString()
    XCTAssertEqual("{\"trigger\":{\"repeating\":{\"repeatInterval\":2}},\"identifier\":{\"managerIdentifier\":\"managerIdentifier1\",\"alertIdentifier\":\"alertIdentifier1\"},\"foregroundContent\":{\"body\":\"body1\",\"isCritical\":false,\"title\":\"title1\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel1\"},\"backgroundContent\":{\"body\":\"body2\",\"isCritical\":false,\"title\":\"title2\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel2\"}}", str)
    }
    
    func testDeviceAlertSilentSoundEncodable() {
        let alert = DeviceAlert(identifier: identifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .immediate, sound: .silence)
        let str = try? alert.encodeToString()
        XCTAssertEqual("{\"trigger\":\"immediate\",\"sound\":\"silence\",\"identifier\":{\"managerIdentifier\":\"managerIdentifier1\",\"alertIdentifier\":\"alertIdentifier1\"},\"foregroundContent\":{\"body\":\"body1\",\"isCritical\":false,\"title\":\"title1\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel1\"},\"backgroundContent\":{\"body\":\"body2\",\"isCritical\":false,\"title\":\"title2\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel2\"}}", str)
    }

    func testDeviceAlertVibrateSoundEncodable() {
        let alert = DeviceAlert(identifier: identifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .immediate, sound: .vibrate)
        let str = try? alert.encodeToString()
        XCTAssertEqual("{\"trigger\":\"immediate\",\"sound\":\"vibrate\",\"identifier\":{\"managerIdentifier\":\"managerIdentifier1\",\"alertIdentifier\":\"alertIdentifier1\"},\"foregroundContent\":{\"body\":\"body1\",\"isCritical\":false,\"title\":\"title1\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel1\"},\"backgroundContent\":{\"body\":\"body2\",\"isCritical\":false,\"title\":\"title2\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel2\"}}", str)
    }

    func testDeviceAlertSoundEncodable() {
        let alert = DeviceAlert(identifier: identifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .immediate, sound: .sound(name: "soundName"))
        let str = try? alert.encodeToString()
        XCTAssertEqual("{\"trigger\":\"immediate\",\"sound\":{\"sound\":{\"name\":\"soundName\"}},\"identifier\":{\"managerIdentifier\":\"managerIdentifier1\",\"alertIdentifier\":\"alertIdentifier1\"},\"foregroundContent\":{\"body\":\"body1\",\"isCritical\":false,\"title\":\"title1\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel1\"},\"backgroundContent\":{\"body\":\"body2\",\"isCritical\":false,\"title\":\"title2\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel2\"}}", str)
    }

    func testDeviceAlertImmediateDecodable() {
        let str = "{\"trigger\":\"immediate\",\"identifier\":{\"managerIdentifier\":\"managerIdentifier1\",\"alertIdentifier\":\"alertIdentifier1\"},\"foregroundContent\":{\"body\":\"body1\",\"isCritical\":false,\"title\":\"title1\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel1\"},\"backgroundContent\":{\"body\":\"body2\",\"isCritical\":false,\"title\":\"title2\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel2\"}}"
        let expected = DeviceAlert(identifier: identifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .immediate)
        let alert = try? DeviceAlert.decode(from: str)
        XCTAssertEqual(expected, alert)
    }

    func testDeviceAlertDelayedDecodable() {
        let str = "{\"trigger\":{\"delayed\":{\"delayInterval\":1}},\"identifier\":{\"managerIdentifier\":\"managerIdentifier1\",\"alertIdentifier\":\"alertIdentifier1\"},\"foregroundContent\":{\"body\":\"body1\",\"isCritical\":false,\"title\":\"title1\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel1\"},\"backgroundContent\":{\"body\":\"body2\",\"isCritical\":false,\"title\":\"title2\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel2\"}}"
        let expected = DeviceAlert(identifier: identifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .delayed(interval: 1.0))
        let alert = try? DeviceAlert.decode(from: str)
        XCTAssertEqual(expected, alert)
    }

    func testDeviceAlertRepeatingDecodable() {
        let str = "{\"trigger\":{\"repeating\":{\"repeatInterval\":2}},\"identifier\":{\"managerIdentifier\":\"managerIdentifier1\",\"alertIdentifier\":\"alertIdentifier1\"},\"foregroundContent\":{\"body\":\"body1\",\"isCritical\":false,\"title\":\"title1\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel1\"},\"backgroundContent\":{\"body\":\"body2\",\"isCritical\":false,\"title\":\"title2\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel2\"}}"
        let expected = DeviceAlert(identifier: identifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .repeating(repeatInterval: 2.0))
        let alert = try? DeviceAlert.decode(from: str)
        XCTAssertEqual(expected, alert)
    }

    func testDeviceAlertSilentSoundDecodable() {
        let str = "{\"trigger\":\"immediate\",\"sound\":\"silence\",\"identifier\":{\"managerIdentifier\":\"managerIdentifier1\",\"alertIdentifier\":\"alertIdentifier1\"},\"foregroundContent\":{\"body\":\"body1\",\"isCritical\":false,\"title\":\"title1\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel1\"},\"backgroundContent\":{\"body\":\"body2\",\"isCritical\":false,\"title\":\"title2\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel2\"}}"
        let expected = DeviceAlert(identifier: identifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .immediate, sound: .silence)
        let alert = try? DeviceAlert.decode(from: str)
        XCTAssertEqual(expected, alert)
    }

    func testDeviceAlertVibrateSoundDecodable() {
        let str = "{\"trigger\":\"immediate\",\"sound\":\"vibrate\",\"identifier\":{\"managerIdentifier\":\"managerIdentifier1\",\"alertIdentifier\":\"alertIdentifier1\"},\"foregroundContent\":{\"body\":\"body1\",\"isCritical\":false,\"title\":\"title1\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel1\"},\"backgroundContent\":{\"body\":\"body2\",\"isCritical\":false,\"title\":\"title2\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel2\"}}"
        let expected = DeviceAlert(identifier: identifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .immediate, sound: .vibrate)
        let alert = try? DeviceAlert.decode(from: str)
        XCTAssertEqual(expected, alert)
    }

    func testDeviceAlertSoundDecodable() {
        let str = "{\"trigger\":\"immediate\",\"sound\":{\"sound\":{\"name\":\"soundName\"}},\"identifier\":{\"managerIdentifier\":\"managerIdentifier1\",\"alertIdentifier\":\"alertIdentifier1\"},\"foregroundContent\":{\"body\":\"body1\",\"isCritical\":false,\"title\":\"title1\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel1\"},\"backgroundContent\":{\"body\":\"body2\",\"isCritical\":false,\"title\":\"title2\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel2\"}}"
        let expected = DeviceAlert(identifier: identifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .immediate, sound: .sound(name: "soundName"))
        let alert = try? DeviceAlert.decode(from: str)
        XCTAssertEqual(expected, alert)
    }
    
    func testDeviceAlertSoundFilename() {
        XCTAssertNil(DeviceAlert.Sound.silence.filename)
        XCTAssertNil(DeviceAlert.Sound.vibrate.filename)
        XCTAssertEqual("foo", DeviceAlert.Sound.sound(name: "foo").filename)
    }
}
