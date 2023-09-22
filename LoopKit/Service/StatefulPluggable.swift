//
//  StatefulPluggable.swift
//  LoopKit
//
//  Created by Nathaniel Hamming on 2023-09-05.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation


public protocol StatefulPlugin {
    var pluginType: StatefulPluggable.Type? { get }
}

public protocol StatefulPluggableProvider {
    /// The stateful plugin with the specified identifier.
    ///
    /// - Parameters:
    ///     - identifier: The identifier of the stateful plugin
    /// - Returns: Either a stateful plugin with matching identifier or nil.
    func statefulPlugin(withIdentifier identifier: String) -> StatefulPluggable?
}

public protocol StatefulPluggableDelegate: AnyObject {
    /// Informs the delegate that the state of the specified plugin was updated and the delegate should persist the plugin. May
    /// be invoked prior to the plugin completing setup.
    ///
    /// - Parameters:
    ///     - plugin: The plugin that updated state.
    func pluginDidUpdateState(_ plugin: StatefulPluggable)

    /// Informs the delegate that the plugin wants deletion.
    ///
    /// - Parameters:
    ///     - plugin: The plugin that wants deletion.
    func pluginWantsDeletion(_ plugin: StatefulPluggable)
}

public protocol StatefulPluggable: Pluggable {
    typealias RawStateValue = [String: Any]

    /// The delegate to notify of plugin updates.
    var stateDelegate: StatefulPluggableDelegate? { get set }

    /// Initializes the plugin with the previously-serialized state.
    ///
    /// - Parameters:
    ///     - rawState: The previously-serialized state of the plugin.
    init?(rawState: RawStateValue)

    /// The current, serializable state of the plugin.
    var rawState: RawStateValue { get }

    /// Is the plugin onboarded and ready for use?
    var isOnboarded: Bool { get }
}
