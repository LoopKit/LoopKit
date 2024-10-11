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

    override func setUp() async throws {
        try await super.setUp()

        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!

        cacheStore = PersistenceController(directoryURL: URL(fileURLWithPath: dir.absoluteString, isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true))

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) -> Void in
            cacheStore.onReady { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    override func tearDown() async throws {
        cacheStore.tearDown()
        cacheStore = nil

        try await super.tearDown()
    }

    deinit {
        cacheStore?.tearDown()
    }
    
}
