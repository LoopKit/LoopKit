//
//  OrientationLock.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 7/28/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


public protocol DeviceOrientationController: AnyObject {
    var supportedInterfaceOrientations: UIInterfaceOrientationMask { get set }
}

/// A class whose lifetime defines the application's supported interface orientations.
///
/// Use the `supportedInterfaceOrientations` modifier on a SwiftUI view to lock its orientation.
/// To function, `OrientationLock.deviceOrientationController` must be assigned prior to use.
public final class OrientationLock {
    private let originalSupportedInterfaceOrientations: UIInterfaceOrientationMask

    /// The global controller for device orientation.
    /// The property must be assigned prior to instantiating any OrientationLock.
    public static weak var deviceOrientationController: DeviceOrientationController?

    fileprivate init(_ supportedInterfaceOrientations: UIInterfaceOrientationMask) {
        assert(Self.deviceOrientationController != nil, "OrientationLock.deviceOrientationController must be assigned prior to constructing an OrientationLock")
        originalSupportedInterfaceOrientations = Self.deviceOrientationController?.supportedInterfaceOrientations ?? .allButUpsideDown
        Self.deviceOrientationController?.supportedInterfaceOrientations = supportedInterfaceOrientations
    }

    deinit {
        Self.deviceOrientationController?.supportedInterfaceOrientations = originalSupportedInterfaceOrientations
    }
}

extension View {
    /// Use the `supportedInterfaceOrientations` modifier on a SwiftUI view to lock its orientation.
    /// To function, `OrientationLock.deviceOrientationController` must be assigned prior to use.
    public func supportedInterfaceOrientations(_ supportedInterfaceOrientations: UIInterfaceOrientationMask) -> some View {
        OrientationLocked(supportedInterfaceOrientations: supportedInterfaceOrientations, content: self)
    }
}

private struct OrientationLocked<Content: View>: View {
    // Annotated with `@State` to ensure SwiftUI keeps the object alive for the duration of the view's lifetime
    @State var orientationLock: OrientationLock
    var content: Content

    init(supportedInterfaceOrientations: UIInterfaceOrientationMask, content: Content) {
        self._orientationLock = State(wrappedValue: OrientationLock(supportedInterfaceOrientations))
        self.content = content
    }

    var body: some View { content }
}
