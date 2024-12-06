//
//  HistoricalOverrideDetailView.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 8/4/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//
import SwiftUI
import LoopKit
import LoopAlgorithm


public struct HistoricalOverrideDetailView: UIViewControllerRepresentable {
    public var override: TemporaryScheduleOverride
    public var glucoseUnit: LoopUnit
    public weak var delegate: AddEditOverrideTableViewControllerDelegate?
    
    public init(
        override: TemporaryScheduleOverride,
        glucoseUnit: LoopUnit,
        delegate: AddEditOverrideTableViewControllerDelegate?
    ) {
        self.override = override
        self.glucoseUnit = glucoseUnit
        self.delegate = delegate
    }
    
    public func makeUIViewController(context: Context) -> AddEditOverrideTableViewController {
        let viewController = AddEditOverrideTableViewController(glucoseUnit: glucoseUnit)
        viewController.inputMode = .viewOverride(override)
        viewController.delegate = delegate
        viewController.view.isUserInteractionEnabled = false // disable interactions while viewing historical data

        return viewController
    }
    
    public func updateUIViewController(_ viewController: AddEditOverrideTableViewController, context: Context) { }
}
