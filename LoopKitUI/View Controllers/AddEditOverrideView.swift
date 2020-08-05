//
//  AddEditOverrideView.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 8/4/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//
import SwiftUI
import LoopKit
import HealthKit

// ANNA TODO: think about renaming
public struct AddEditOverrideView: UIViewControllerRepresentable {
    public var inputMode: AddEditOverrideTableViewController.InputMode
    public var glucoseUnit: HKUnit
    public weak var delegate: AddEditOverrideTableViewControllerDelegate?
    
    public init(
        inputMode: AddEditOverrideTableViewController.InputMode,
        glucoseUnit: HKUnit,
        delegate: AddEditOverrideTableViewControllerDelegate?
    ) {
        self.inputMode = inputMode
        self.glucoseUnit = glucoseUnit
        self.delegate = delegate
    }
    
    public func makeUIViewController(context: Context) -> AddEditOverrideTableViewController {
        let viewController = AddEditOverrideTableViewController(glucoseUnit: glucoseUnit)
        viewController.inputMode = inputMode
        viewController.delegate = delegate

        return viewController
    }
    
    public func updateUIViewController(_ viewController: AddEditOverrideTableViewController, context: Context) {
        
    }
}
