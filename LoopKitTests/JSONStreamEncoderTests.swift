//
//  JSONStreamEncoderTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 8/26/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import LoopKit

class JSONStreamEncoderTests: XCTestCase {
    var outputStream: MockOutputStream!
    var encoder: JSONStreamEncoder!

    override func setUp() {
        outputStream = MockOutputStream()
        encoder = JSONStreamEncoder(stream: outputStream)
    }

    func testEmpty() {
        XCTAssertNil(encoder.close())
        XCTAssertEqual(outputStream.string, "[]")
    }

    func testMultipleClose() {
        XCTAssertNil(encoder.close())
        XCTAssertNil(encoder.close())
    }

    func testCloseError() {
        let mockError = MockError()
        outputStream.error = mockError
        XCTAssertEqual(encoder.close() as! MockError, mockError)
    }

    func testEncode() {
        let values = [MockValue(left: "Alpha", center: 1, right: dateFormatter.date(from: "2020-01-02T03:02:00Z")!),
                      MockValue(left: "Bravo", center: 2, right: dateFormatter.date(from: "2020-01-02T03:04:00Z")!),
                      MockValue(left: "Charlie", center: 3, right: dateFormatter.date(from: "2020-01-02T03:06:00Z")!)]
        XCTAssertNoThrow(try encoder.encode(values))
        XCTAssertNil(encoder.close())
        XCTAssertEqual(outputStream.string, """
[
{"center":1,"left":"Alpha","right":"2020-01-02T03:02:00.000Z"},
{"center":2,"left":"Bravo","right":"2020-01-02T03:04:00.000Z"},
{"center":3,"left":"Charlie","right":"2020-01-02T03:06:00.000Z"}
]
"""
        )
    }

    func testEncodeEmpty() {
        XCTAssertNoThrow(try encoder.encode([MockValue]()))
        XCTAssertNil(encoder.close())
        XCTAssertEqual(outputStream.string, "[]")
    }

    func testEncodeClosed() {
        let values = [MockValue(left: "Alpha", center: 1, right: dateFormatter.date(from: "2020-01-02T03:02:00Z")!)]
        XCTAssertNil(encoder.close())
        XCTAssertThrowsError(try encoder.encode(values)) { error in
            XCTAssertEqual(error as! JSONStreamEncoderError, JSONStreamEncoderError.encoderClosed)
        }
    }

    func testEncodeError() {
        let values = [MockValue(left: "Alpha", center: 1, right: dateFormatter.date(from: "2020-01-02T03:02:00Z")!)]
        let mockError = MockError()
        outputStream.error = mockError
        XCTAssertThrowsError(try encoder.encode(values)) { error in
            XCTAssertEqual(error as! MockError, mockError)
        }
    }

    private let dateFormatter = ISO8601DateFormatter()
}

fileprivate struct MockValue: Codable {
    let left: String
    let center: Int
    let right: Date
}

fileprivate struct MockError: Error, Equatable {}
