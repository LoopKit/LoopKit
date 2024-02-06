//
//  OpenMockPumpSettingsOnLongPressGesture.swift
//  MockKitUI
//
//  Created by Nathaniel Hamming on 2023-05-18.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import MockKit

extension View {
    func openMockPumpSettingsOnLongPress(enabled: Bool = true, minimumDuration: Double = 5, pumpManager: MockPumpManager, supportedInsulinTypes: [InsulinType]) -> some View {
        modifier(OpenMockPumpSettingsOnLongPressGesture(enabled: enabled, minimumDuration: minimumDuration, pumpManager: pumpManager, supportedInsulinTypes: supportedInsulinTypes))
    }
}

fileprivate struct OpenMockPumpSettingsOnLongPressGesture: ViewModifier {
    private let enabled: Bool
    private let minimumDuration: TimeInterval
    private let pumpManager: MockPumpManager
    private let supportedInsulinTypes: [InsulinType]
    @State private var mockPumpSettingsDisplayed = false

    init(enabled: Bool, minimumDuration: Double, pumpManager: MockPumpManager, supportedInsulinTypes: [InsulinType]) {
        self.enabled = enabled
        self.minimumDuration = minimumDuration
        self.pumpManager = pumpManager
        self.supportedInsulinTypes = supportedInsulinTypes
    }

    func body(content: Content) -> some View {
        modifiedContent(content: content)
    }
    
    func modifiedContent(content: Content) -> some View {
        ZStack {
            content
                .onLongPressGesture(minimumDuration: minimumDuration) {
                    mockPumpSettingsDisplayed = true
                }
            NavigationLink(destination: MockPumpManagerControlsView(pumpManager: pumpManager, supportedInsulinTypes: supportedInsulinTypes), isActive: $mockPumpSettingsDisplayed) {
                EmptyView()
            }
            .opacity(0) // <- Hides the Chevron
            .buttonStyle(PlainButtonStyle())
            .disabled(true)
        }
    }
}
