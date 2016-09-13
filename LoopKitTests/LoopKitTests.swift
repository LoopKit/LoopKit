//
//  LoopKitTests.swift
//  LoopKitTests
//
//  Created by Nathan Racklyeft on 1/18/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import XCTest
import Foundation

public typealias JSONDictionary = [String: Any]


extension XCTestCase {
    public var bundle: Bundle {
        return Bundle(for: type(of: self))
    }

    public func loadFixture<T>(_ resourceName: String) -> T {
        let path = bundle.path(forResource: resourceName, ofType: "json")!
        return try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path)), options: []) as! T
    }
}
