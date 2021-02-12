//
//  SupportUI.swift
//  LoopKitUI
//
//  Created by Darin Krauss on 12/10/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit

public protocol SupportInfoProvider {
    var pumpStatus: PumpManagerStatus? { get }
    var cgmDevice: HKDevice? { get }
    var localizedAppNameAndVersion: String { get }
    func generateIssueReport(completion: @escaping (String) -> Void)
}

public protocol SupportUI {
    /// The unique identifier of this type of support.
    var supportIdentifier: String { get }

    /// Provides support menu item.
    ///
    /// - Parameters:
    ///   - supportInfoProvider: A provider of additional support information.
    ///   - urlHandler: A handler to open any URLs.
    /// - Returns: A view that will be used in a support menu for providing user support.
    func supportMenuItem(supportInfoProvider: SupportInfoProvider, urlHandler: @escaping (URL) -> Void) -> AnyView?
}
