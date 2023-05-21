//
//  MockPumpManagerControlsView.swift
//  MockKitUI
//
//  Created by Nathaniel Hamming on 2023-05-18.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import MockKit

struct MockPumpManagerControlsView: UIViewControllerRepresentable {
    private let pumpManager: MockPumpManager
    private let supportedInsulinTypes: [InsulinType]

    init(pumpManager: MockPumpManager, supportedInsulinTypes: [InsulinType]) {
        self.pumpManager = pumpManager
        self.supportedInsulinTypes = supportedInsulinTypes
    }

    final class Coordinator: NSObject {
        private let parent: MockPumpManagerControlsView

        init(_ parent: MockPumpManagerControlsView) {
            self.parent = parent
        }
    }

    func makeUIViewController(context: Context) -> UIViewController {
        return MockPumpManagerSettingsViewController(pumpManager: pumpManager, supportedInsulinTypes: supportedInsulinTypes)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }
}
