//
//  CarbEntryEditViewControllerTests.swift
//  LoopKit
//
//  Created by Jaim Zuber on 2/7/17.
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
@testable import LoopKit

/// These tests have been disabled until they can be properly rewritten as actual UI tests
class CarbEntryEditViewControllerTests: XCTestCase {

    var vc: CarbKit.CarbEntryEditViewController!
    var storyboard: UIStoryboard!
    
    var navigationDelegateStub: CarbEntryNavigationDelegateStub!
    
    override func setUp() {
        super.setUp()
        storyboard = UIStoryboard(name: "CarbKit", bundle: Bundle(for: type(of: self)))
        vc = storyboard.instantiateViewController(withIdentifier: "CarbEntryEditViewController") as! CarbEntryEditViewController
        let _ = vc.view
        
        navigationDelegateStub = CarbEntryNavigationDelegateStub()
        vc.navigationDelegate = navigationDelegateStub
    }
    
    func testAbsorptionValidationFailure() {
        vc.originalCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 1), startDate: Date(), foodType: nil, absorptionTime: .minutes(1000))

        let shouldPerform = vc.shouldPerformSegue(withIdentifier: "", sender: vc.saveButtonItem)
        
        XCTAssertFalse(shouldPerform)
        XCTAssertTrue(navigationDelegateStub.absorptionTimeValidationWarningWasCalled)
        XCTAssertFalse(navigationDelegateStub.quantityValidationWarningWasCalled)
    }
    
    func testAbsorptionValidationSuccess() {
        vc.originalCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 1), startDate: Date(), foodType: nil, absorptionTime: TimeInterval(hours: 7))

        let shouldPerform = vc.shouldPerformSegue(withIdentifier: "", sender: vc.saveButtonItem)

        XCTAssertTrue(shouldPerform)
        XCTAssertFalse(navigationDelegateStub.absorptionTimeValidationWarningWasCalled)
        XCTAssertFalse(navigationDelegateStub.quantityValidationWarningWasCalled)
    }

    func testNoEntry() {
        XCTAssertFalse(vc.shouldPerformSegue(withIdentifier: "", sender: vc.saveButtonItem))
        XCTAssertFalse(navigationDelegateStub.absorptionTimeValidationWarningWasCalled)
        XCTAssertFalse(navigationDelegateStub.quantityValidationWarningWasCalled)
    }

    func testQuantityValidationSuccess() {
        for value in [150, 250] as [Double] {
            vc.originalCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: value), startDate: Date(), foodType: nil, absorptionTime: .minutes(180))
            XCTAssertTrue(vc.shouldPerformSegue(withIdentifier: "", sender: vc.saveButtonItem))
        }

        XCTAssertFalse(navigationDelegateStub.absorptionTimeValidationWarningWasCalled)
        XCTAssertFalse(navigationDelegateStub.quantityValidationWarningWasCalled)
    }

    func testQuantityValidationFailure() {

        for value in [0, -100, 251, 500] as [Double] {
            vc.originalCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: value), startDate: Date(), foodType: nil, absorptionTime: .minutes(180))
            XCTAssertFalse(vc.shouldPerformSegue(withIdentifier: "", sender: vc.saveButtonItem))
        }

        XCTAssertFalse(navigationDelegateStub.absorptionTimeValidationWarningWasCalled)
        XCTAssertTrue(navigationDelegateStub.quantityValidationWarningWasCalled)
    }

    class CarbEntryNavigationDelegateStub: CarbEntryNavigationDelegate {
        var absorptionTimeValidationWarningWasCalled = false
        var quantityValidationWarningWasCalled = false

        override func showAbsorptionTimeValidationWarning(for viewController: UIViewController, maxAbsorptionTime: TimeInterval) {
            absorptionTimeValidationWarningWasCalled = true
        }

        override func showMaxQuantityValidationWarning(for viewController: UIViewController, maxQuantityGrams: Double) {
            quantityValidationWarningWasCalled = true
        }
    }
}
