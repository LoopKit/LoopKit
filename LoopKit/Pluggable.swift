//
//  Pluggable.swift
//  LoopKit
//
//  Created by Nathaniel Hamming on 2023-09-08.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

public protocol Pluggable: AnyObject {
    /// The unique identifier for this plugin.
    var pluginIdentifier: String { get }
    
    /// A plugin may need a reference to another plugin. This callback allows for such a reference.
    /// It is called once during app initialization after plugins are initialized and again as new plugins are added and initialized.
    func initializationComplete(for pluggables: [Pluggable])
    
    /// A plugin may require another plugin. This callback informs this dependency.
    /// Often this is called as apart of `initializationComplete(for pluggables: [Pluggable])`
    func markAsDepedency(_ isDependency: Bool)
}

public extension Pluggable {
    func initializationComplete(for pluggables: [Pluggable]) { } // optional
    func markAsDepedency(_ isDependency: Bool) { } // optional
}
