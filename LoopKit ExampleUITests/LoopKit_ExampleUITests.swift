//
//  LoopKit_ExampleUITests.swift
//  LoopKit ExampleUITests
//
//  Created by Nathan Racklyeft on 2/24/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import XCTest

class LoopKit_ExampleUITests: XCTestCase {
        
    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        XCUIApplication().launch()

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }
    
}
