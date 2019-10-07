//
//  DiagnosticLogTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 8/23/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import XCTest
import os.log

@testable import LoopKit

class DiagnosticLogTests: XCTestCase {
    
    fileprivate var testLoggingService: TestLoggingService!
    
    override func setUp() {
        testLoggingService = TestLoggingService()
        SharedLoggingService.instance = testLoggingService
    }
    
    override func tearDown() {
        SharedLoggingService.instance = nil
        testLoggingService = nil
    }
    
    func testInitializer() {
        XCTAssertNotNil(DiagnosticLog(subsystem: "subsystem", category: "category"))
    }
    
    func testDebugWithoutArguments() {
        let diagnosticLog = DiagnosticLog(subsystem: "debug subsystem", category: "debug category")
        
        diagnosticLog.debug("debug message without arguments")
        
        XCTAssertEqual(testLoggingService.message.description, "debug message without arguments")
        XCTAssertEqual(testLoggingService.subsystem, "debug subsystem")
        XCTAssertEqual(testLoggingService.category, "debug category")
        XCTAssertEqual(testLoggingService.type, .debug)
        XCTAssertEqual(testLoggingService.args.count, 0)
    }
    
    func testDebugWithArguments() {
        let diagnosticLog = DiagnosticLog(subsystem: "debug subsystem", category: "debug category")
        
        diagnosticLog.debug("debug message with arguments", "a")
        
        XCTAssertEqual(testLoggingService.message.description, "debug message with arguments")
        XCTAssertEqual(testLoggingService.subsystem, "debug subsystem")
        XCTAssertEqual(testLoggingService.category, "debug category")
        XCTAssertEqual(testLoggingService.type, .debug)
        XCTAssertEqual(testLoggingService.args.count, 1)
    }
    
    func testInfoWithoutArguments() {
        let diagnosticLog = DiagnosticLog(subsystem: "info subsystem", category: "info category")
        
        diagnosticLog.info("info message without arguments")
        
        XCTAssertEqual(testLoggingService.message.description, "info message without arguments")
        XCTAssertEqual(testLoggingService.subsystem, "info subsystem")
        XCTAssertEqual(testLoggingService.category, "info category")
        XCTAssertEqual(testLoggingService.type, .info)
        XCTAssertEqual(testLoggingService.args.count, 0)
    }
    
    func testInfoWithArguments() {
        let diagnosticLog = DiagnosticLog(subsystem: "info subsystem", category: "info category")
        
        diagnosticLog.info("info message with arguments", "a", "b")
        
        XCTAssertEqual(testLoggingService.message.description, "info message with arguments")
        XCTAssertEqual(testLoggingService.subsystem, "info subsystem")
        XCTAssertEqual(testLoggingService.category, "info category")
        XCTAssertEqual(testLoggingService.type, .info)
        XCTAssertEqual(testLoggingService.args.count, 2)
    }
    
    func testDefaultWithoutArguments() {
        let diagnosticLog = DiagnosticLog(subsystem: "default subsystem", category: "default category")
        
        diagnosticLog.default("default message without arguments")
        
        XCTAssertEqual(testLoggingService.message.description, "default message without arguments")
        XCTAssertEqual(testLoggingService.subsystem, "default subsystem")
        XCTAssertEqual(testLoggingService.category, "default category")
        XCTAssertEqual(testLoggingService.type, .default)
        XCTAssertEqual(testLoggingService.args.count, 0)
    }
    
    func testDefaultWithArguments() {
        let diagnosticLog = DiagnosticLog(subsystem: "default subsystem", category: "default category")
        
        diagnosticLog.default("default message with arguments", "a", "b", "c")
        
        XCTAssertEqual(testLoggingService.message.description, "default message with arguments")
        XCTAssertEqual(testLoggingService.subsystem, "default subsystem")
        XCTAssertEqual(testLoggingService.category, "default category")
        XCTAssertEqual(testLoggingService.type, .default)
        XCTAssertEqual(testLoggingService.args.count, 3)
    }
    
    func testErrorWithoutArguments() {
        let diagnosticLog = DiagnosticLog(subsystem: "error subsystem", category: "error category")
        
        diagnosticLog.error("error message without arguments")
        
        XCTAssertEqual(testLoggingService.message.description, "error message without arguments")
        XCTAssertEqual(testLoggingService.subsystem, "error subsystem")
        XCTAssertEqual(testLoggingService.category, "error category")
        XCTAssertEqual(testLoggingService.type, .error)
        XCTAssertEqual(testLoggingService.args.count, 0)
    }
    
    func testErrorWithArguments() {
        let diagnosticLog = DiagnosticLog(subsystem: "error subsystem", category: "error category")
        
        diagnosticLog.error("error message with arguments", "a", "b", "c", "d")
        
        XCTAssertEqual(testLoggingService.message.description, "error message with arguments")
        XCTAssertEqual(testLoggingService.subsystem, "error subsystem")
        XCTAssertEqual(testLoggingService.category, "error category")
        XCTAssertEqual(testLoggingService.type, .error)
        XCTAssertEqual(testLoggingService.args.count, 4)
    }
    
}

fileprivate class TestLoggingService: LoggingService {
    
    var message: StaticString!
    
    var subsystem: String!
    
    var category: String!
    
    var type: OSLogType!
    
    var args: [CVarArg]!
    
    init() {}
    
    func log (_ message: StaticString, subsystem: String, category: String, type: OSLogType, _ args: [CVarArg]) {
        self.message = message
        self.subsystem = subsystem
        self.category = category
        self.type = type
        self.args = args
    }
}
