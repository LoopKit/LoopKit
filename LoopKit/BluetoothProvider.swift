//
//  BluetoothProvider.swift
//  LoopKit
//
//  Created by Darin Krauss on 3/1/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation

public enum BluetoothAuthorization: Int {
    /// User has not yet made a choice regarding whether the application may use Bluetooth.
    case notDetermined

    /// This application is not authorized to use Bluetooth. The user cannot change this application’s status,
    case restricted

    /// User has explicitly denied this application from using Bluetooth.
    case denied

    /// User has authorized this application to use Bluetooth.
    case authorized
}

public enum BluetoothState: Int {
    /// State unknown, update imminent.
    case unknown

    /// The connection with the system service was momentarily lost, update imminent.
    case resetting

    /// The platform doesn't support the Bluetooth Low Energy Central/Client role.
    case unsupported

    /// The application is not authorized to use the Bluetooth Low Energy role.
    case unauthorized

    /// Bluetooth is currently powered off.
    case poweredOff

    /// Bluetooth is currently powered on and available to use.
    case poweredOn
}

public protocol BluetoothObserver: AnyObject {
    /// Informs the observer that the Bluetooth state has changed to the given value.
    ///
    /// - Parameters:
    ///     - state: The latest Bluetooth state.
    func bluetoothDidUpdateState(_ state: BluetoothState)
}

public protocol BluetoothProvider: AnyObject {
    /// The current Bluetooth authorization.
    var bluetoothAuthorization: BluetoothAuthorization { get }

    /// The current Bluetooth state. If Bluetooth has not been authorized then returns .unknown.
    var bluetoothState: BluetoothState { get }

    /// Authorize Bluetooth. Should only be invoked if bluetoothAuthorization is .notDetermined.
    ///
    /// - Parameters:
    ///     - completion: Invoked when Bluetooth authorization is complete along with the resulting authorization.
    func authorizeBluetooth(_ completion: @escaping (BluetoothAuthorization) -> Void)

    /// Start observing Bluetooth changes.
    ///
    /// - Parameters:
    ///     - observer: The observer observing Bluetooth changes.
    ///     - queue: The Dispatch queue upon which to notify the observer of Bluetooth changes.
    func addBluetoothObserver(_ observer: BluetoothObserver, queue: DispatchQueue)

    /// Stop observing Bluetooth changes.
    ///
    /// - Parameters:
    ///     - observer: The observer observing Bluetooth changes.
    func removeBluetoothObserver(_ observer: BluetoothObserver)
}
