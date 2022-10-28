//
//  AlertTests.swift
//  LoopKitTests
//
//  Created by Rick Pasetto on 5/1/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit

class AlertTests: XCTestCase {
    let identifier = Alert.Identifier(managerIdentifier: "managerIdentifier1", alertIdentifier: "alertIdentifier1")
    let foregroundContent = Alert.Content(title: "title1", body: "body1", acknowledgeActionButtonLabel: "acknowledgeActionButtonLabel1")
    let backgroundContent = Alert.Content(title: "title2", body: "body2", acknowledgeActionButtonLabel: "acknowledgeActionButtonLabel2")

    func testIdentifierValue() {
        XCTAssertEqual("managerIdentifier1.alertIdentifier1", identifier.value)
    }
    
    func testAlertImmediateEncodable() {
        let alert = Alert(identifier: identifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .immediate)
        let str = try? alert.encodeToString()
    XCTAssertEqual("{\"trigger\":\"immediate\",\"interruptionLevel\":\"timeSensitive\",\"identifier\":{\"managerIdentifier\":\"managerIdentifier1\",\"alertIdentifier\":\"alertIdentifier1\"},\"foregroundContent\":{\"title\":\"title1\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel1\",\"body\":\"body1\"},\"backgroundContent\":{\"title\":\"title2\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel2\",\"body\":\"body2\"}}", str)
    }
    
    func testAlertDelayedEncodable() {
        let alert = Alert(identifier: identifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .delayed(interval: 1.0))
        let str = try? alert.encodeToString()
    XCTAssertEqual("{\"trigger\":{\"delayed\":{\"delayInterval\":1}},\"interruptionLevel\":\"timeSensitive\",\"identifier\":{\"managerIdentifier\":\"managerIdentifier1\",\"alertIdentifier\":\"alertIdentifier1\"},\"foregroundContent\":{\"title\":\"title1\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel1\",\"body\":\"body1\"},\"backgroundContent\":{\"title\":\"title2\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel2\",\"body\":\"body2\"}}", str)
    }
    
    func testAlertRepeatingEncodable() {
        let alert = Alert(identifier: identifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .repeating(repeatInterval: 2.0))
        let str = try? alert.encodeToString()
    XCTAssertEqual("{\"trigger\":{\"repeating\":{\"repeatInterval\":2}},\"interruptionLevel\":\"timeSensitive\",\"identifier\":{\"managerIdentifier\":\"managerIdentifier1\",\"alertIdentifier\":\"alertIdentifier1\"},\"foregroundContent\":{\"title\":\"title1\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel1\",\"body\":\"body1\"},\"backgroundContent\":{\"title\":\"title2\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel2\",\"body\":\"body2\"}}", str)
    }

    func testAlertVibrateSoundEncodable() {
        let alert = Alert(identifier: identifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .immediate, sound: .vibrate)
        let str = try? alert.encodeToString()
        XCTAssertEqual("{\"trigger\":\"immediate\",\"interruptionLevel\":\"timeSensitive\",\"sound\":\"vibrate\",\"identifier\":{\"managerIdentifier\":\"managerIdentifier1\",\"alertIdentifier\":\"alertIdentifier1\"},\"foregroundContent\":{\"title\":\"title1\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel1\",\"body\":\"body1\"},\"backgroundContent\":{\"title\":\"title2\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel2\",\"body\":\"body2\"}}", str)
    }

    func testAlertSoundEncodable() {
        let alert = Alert(identifier: identifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .immediate, sound: .sound(name: "soundName"))
        let str = try? alert.encodeToString()
        XCTAssertEqual("{\"trigger\":\"immediate\",\"interruptionLevel\":\"timeSensitive\",\"sound\":{\"sound\":{\"name\":\"soundName\"}},\"identifier\":{\"managerIdentifier\":\"managerIdentifier1\",\"alertIdentifier\":\"alertIdentifier1\"},\"foregroundContent\":{\"title\":\"title1\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel1\",\"body\":\"body1\"},\"backgroundContent\":{\"title\":\"title2\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel2\",\"body\":\"body2\"}}", str)
    }

    func testAlertImmediateDecodable() {
        let str = "{\"trigger\":\"immediate\",\"interruptionLevel\":\"timeSensitive\",\"identifier\":{\"managerIdentifier\":\"managerIdentifier1\",\"alertIdentifier\":\"alertIdentifier1\"},\"foregroundContent\":{\"body\":\"body1\",\"title\":\"title1\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel1\"},\"backgroundContent\":{\"body\":\"body2\",\"title\":\"title2\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel2\"}}"
        let expected = Alert(identifier: identifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .immediate)
        let alert = try? Alert.decode(from: str)
        XCTAssertEqual(expected, alert)
    }

    func testAlertDelayedDecodable() {
        let str = "{\"trigger\":{\"delayed\":{\"delayInterval\":1}},\"interruptionLevel\":\"timeSensitive\",\"identifier\":{\"managerIdentifier\":\"managerIdentifier1\",\"alertIdentifier\":\"alertIdentifier1\"},\"foregroundContent\":{\"body\":\"body1\",\"title\":\"title1\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel1\"},\"backgroundContent\":{\"body\":\"body2\",\"title\":\"title2\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel2\"}}"
        let expected = Alert(identifier: identifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .delayed(interval: 1.0))
        let alert = try? Alert.decode(from: str)
        XCTAssertEqual(expected, alert)
    }

    func testAlertRepeatingDecodable() {
        let str = "{\"trigger\":{\"repeating\":{\"repeatInterval\":2}},\"interruptionLevel\":\"timeSensitive\",\"identifier\":{\"managerIdentifier\":\"managerIdentifier1\",\"alertIdentifier\":\"alertIdentifier1\"},\"foregroundContent\":{\"body\":\"body1\",\"title\":\"title1\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel1\"},\"backgroundContent\":{\"body\":\"body2\",\"title\":\"title2\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel2\"}}"
        let expected = Alert(identifier: identifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .repeating(repeatInterval: 2.0))
        let alert = try? Alert.decode(from: str)
        XCTAssertEqual(expected, alert)
    }

    func testAlertVibrateSoundDecodable() {
        let str = "{\"trigger\":\"immediate\",\"sound\":\"vibrate\",\"interruptionLevel\":\"timeSensitive\",\"identifier\":{\"managerIdentifier\":\"managerIdentifier1\",\"alertIdentifier\":\"alertIdentifier1\"},\"foregroundContent\":{\"body\":\"body1\",\"title\":\"title1\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel1\"},\"backgroundContent\":{\"body\":\"body2\",\"title\":\"title2\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel2\"}}"
        let expected = Alert(identifier: identifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .immediate, sound: .vibrate)
        let alert = try? Alert.decode(from: str)
        XCTAssertEqual(expected, alert)
    }

    func testAlertSoundDecodable() {
        let str = "{\"trigger\":\"immediate\",\"sound\":{\"sound\":{\"name\":\"soundName\"}},\"interruptionLevel\":\"timeSensitive\",\"identifier\":{\"managerIdentifier\":\"managerIdentifier1\",\"alertIdentifier\":\"alertIdentifier1\"},\"foregroundContent\":{\"body\":\"body1\",\"title\":\"title1\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel1\"},\"backgroundContent\":{\"body\":\"body2\",\"title\":\"title2\",\"acknowledgeActionButtonLabel\":\"acknowledgeActionButtonLabel2\"}}"
        let expected = Alert(identifier: identifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .immediate, sound: .sound(name: "soundName"))
        let alert = try? Alert.decode(from: str)
        XCTAssertEqual(expected, alert)
    }
    
    func testAlertSoundFilename() {
        XCTAssertNil(Alert.Sound.vibrate.filename)
        XCTAssertEqual("foo", Alert.Sound.sound(name: "foo").filename)
    }
}

extension Alert {
    enum CodableError: Swift.Error { case encodeFailed, decodeFailed }
    func encode() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(self)
    }
    static func decode(from data: Data) throws -> Alert {
        let decoder = JSONDecoder()
        return try decoder.decode(Alert.self, from: data)
    }
    func encodeToString() throws -> String {
        let data = try encode()
        guard let result = String(data: data, encoding: .utf8) else {
            throw CodableError.encodeFailed
        }
        return result
    }
    static func decode(from string: String) throws -> Alert {
        guard let data = string.data(using: .utf8) else {
            throw CodableError.decodeFailed
        }
        return try decode(from: data)
    }
}

