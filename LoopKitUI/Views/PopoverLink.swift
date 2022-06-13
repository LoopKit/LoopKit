//
//  PopoverLink.swift
//
//  Created by Manuel Weiel on 09.07.20.
//
// From https://manuel.weiel.eu/bringing-the-simplicity-of-navigationlink-to-popovers/

import SwiftUI

public struct PopoverLink<Label, Destination> : View where Label : View, Destination : View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    private let destination: Destination
    private let label: Label
    private var isActive: Binding<Bool>?
    private var isFullScreen: Bool = false
    @State private var internalIsActive = false

    public init(_ localizedText: Text, destination: Destination) where Label == Text {
        self.init(destination: destination, label: { localizedText })
    }
    
    /// Creates an instance that presents `destination`.
    public init(destination: Destination, @ViewBuilder label: () -> Label) {
        self.destination = destination
        self.label = label()
    }

    /// Creates an instance that presents `destination` when active.
    public init(destination: Destination, isActive: Binding<Bool>, @ViewBuilder label: () -> Label) {
        self.destination = destination
        self.label = label()
        self.isActive = isActive
    }
    
    private init(_ other: PopoverLink, isFullScreen: Bool) {
        self.destination = other.destination
        self.isActive = other.isActive
        self.label = other.label
        self.isFullScreen = isFullScreen
    }

    private func popoverButton() -> some View {
        Button {
            (isActive ?? _internalIsActive.projectedValue).wrappedValue = true
        } label: {
            label
        }
    }

    /// The content and behavior of the view.
    public var body: some View {
        if isFullScreen {
            popoverButton().fullScreenCover(isPresented: (isActive ?? _internalIsActive.projectedValue)) {
                destination
            }
        } else {
            if horizontalSizeClass == .compact {
                popoverButton().sheet(isPresented: (isActive ?? _internalIsActive.projectedValue)) {
                    destination
                }
            } else {
                popoverButton().popover(isPresented: (isActive ?? _internalIsActive.projectedValue)) {
                    destination
                }
            }
        }
    }
}

extension PopoverLink {
    public func fullScreen() -> PopoverLink {
        PopoverLink(self, isFullScreen: true)
    }
}
