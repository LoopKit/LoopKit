//
//  CarbEntryEditViewControllerTests.swift
//  LoopKit
//
//  Created by Jaim Zuber on 2/7/17.
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import CarbKit

class CarbEntryEditViewControllerTests: XCTestCase {
    
    var baseVC: CarbEntryTableViewController!
    var sut: CarbKit.CarbEntryEditViewController!
    var storyboard: UIStoryboard!
    
    var navigationDelegateStub: CarbEntryNavigationDelegateStub!
    var tableViewStub: TableViewStub!
    
    override func setUp() {
        super.setUp()
        storyboard = UIStoryboard(name: "CarbKit", bundle: Bundle(for: type(of:self)))
        sut = storyboard.instantiateViewController(withIdentifier: "CarbEntryEditViewController") as! CarbEntryEditViewController
        let _ = sut.view
        
        navigationDelegateStub = CarbEntryNavigationDelegateStub()
        sut.navigationDelegate = navigationDelegateStub
        
        tableViewStub = TableViewStub(frame: CGRect.zero)
        sut.tableView = tableViewStub
        
        sut.navigationDelegate = navigationDelegateStub
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSanity() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertNotNil(sut)
    }
    
    func testAbsorptionValidationFailureDoesntCallSegue() {
        tableViewStub.absorptionViewCell = createAbsoprtionCell(withValue: 1000)
        
        sut.saveButtonPressed(sut.saveButtonItem)
        
        XCTAssertFalse(navigationDelegateStub.performSegueWasCalled)
    }
    
    func testAbsorptionValidationSuccessCallsSegue() {
        tableViewStub.absorptionViewCell = createAbsoprtionCell(withValue: 500)

        sut.saveButtonPressed(sut.saveButtonItem)
        
        XCTAssertEqual(navigationDelegateStub.performSegueArguments?.identifier, CarbEntryEditViewController.SaveUnwindSegue)
    }
    
    func testPassedValidationDoesntShowWarning() {
        tableViewStub.absorptionViewCell = createAbsoprtionCell(withValue: 998)
        
        sut.saveButtonPressed(sut.saveButtonItem)
        
        XCTAssertFalse(navigationDelegateStub.showAbsorptionTimeValidationWarningWasCalled)
    }
    
    func testFailedValidationPresentsWarning() {
        tableViewStub.absorptionViewCell = createAbsoprtionCell(withValue: 1000)
        
        sut.saveButtonPressed(sut.saveButtonItem)
        
        // should present a warning
        XCTAssertTrue(navigationDelegateStub.showAbsorptionTimeValidationWarningWasCalled)
    }
    
    func createAbsoprtionCell(withValue value: Int) -> AbsorptionTimeTextFieldTableViewCell{
        let absorptionViewCell = AbsorptionTimeTextFieldTableViewCell()
        absorptionViewCell.textField = UITextField()
        absorptionViewCell.number =  NSNumber(value: value)
        
        return absorptionViewCell
    }
    
    class CarbEntryNavigationDelegateStub : CarbEntryNavigationDelegate {
        var performSegueArguments: (identifier: String, sender: Any?, viewController: UIViewController)?
        var performSegueWasCalled: Bool { return performSegueArguments != nil }
        
        var showAbsorptionTimeValidationWarningWasCalled = false
        
        override func performSegue(withIdentifier identifier: String, sender: Any?, for viewController: UIViewController) {
            
            performSegueArguments = (identifier, sender, viewController)
        }
        
        override func showAbsorptionTimeValidationWarning(for viewController: UIViewController) {
            showAbsorptionTimeValidationWarningWasCalled = true
        }
    }
    
    class TableViewStub: UITableView {
        let absorptionTimeIndex = IndexPath(row: CarbEntryEditViewController.Row.absorptionTime.rawValue, section: 0)
        
        var absorptionViewCell: AbsorptionTimeTextFieldTableViewCell?
        
        override init(frame: CGRect, style: UITableViewStyle) {
            super.init(frame: frame, style: style)
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func cellForRow(at indexPath: IndexPath) -> UITableViewCell? {
            if indexPath == absorptionTimeIndex {
                return absorptionViewCell
            }
            
            return UITableViewCell()
        }
    }
}
