//
//  MockCGMManagerControlsView.swift
//  MockKitUI
//
//  Created by Nathaniel Hamming on 2023-05-18.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKitUI
import MockKit

struct MockCGMManagerControlsView: UIViewControllerRepresentable {
    private let cgmManager: MockCGMManager
    private let displayGlucoseUnitObservable: DisplayGlucoseUnitObservable

    init(cgmManager: MockCGMManager, displayGlucoseUnitObservable: DisplayGlucoseUnitObservable) {
        self.cgmManager = cgmManager
        self.displayGlucoseUnitObservable = displayGlucoseUnitObservable
    }

    final class Coordinator: NSObject {
        private let parent: MockCGMManagerControlsView

        init(_ parent: MockCGMManagerControlsView) {
            self.parent = parent
        }
    }

    func makeUIViewController(context: Context) -> UIViewController {
        return MockCGMManagerSettingsViewController(cgmManager: cgmManager, displayGlucoseUnitObservable: displayGlucoseUnitObservable)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }
}
