//
//  CollectionTests.swift
//  LoopKitTests
//
//  Created by Pete Schwamb on 9/2/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit


class CollectionTests: XCTestCase {

    func testChunkedWithEmptyArray() {
        let result = [].chunked(into: 5)
        XCTAssertTrue(result.isEmpty)
    }
    
    func testChunkedWithArrayEvenMultipleOfChunkSize() {
        let result = [1,2,3,4].chunked(into: 2)
        XCTAssertEqual([[1,2], [3,4]], result)
    }

    func testArrayChunkedWithModuloRemainder() {
        let result = [1,2,3].chunked(into: 2)
        XCTAssertEqual([[1,2], [3]], result)
    }
}
