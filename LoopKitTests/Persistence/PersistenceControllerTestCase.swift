//
//  PersistenceControllerTestCase.swift
//  LoopKitTests
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit

class PersistenceControllerTestCase: XCTestCase {

    var cacheStore: PersistenceController!

    override func setUp() {
        super.setUp()

        cacheStore = PersistenceController(directoryURL: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true))
    }

    override func tearDown() {
        cacheStore.tearDown()
        cacheStore = nil

        super.tearDown()
    }

    deinit {
        cacheStore?.tearDown()
    }
    
}
