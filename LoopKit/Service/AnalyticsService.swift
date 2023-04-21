//
//  AnalyticsService.swift
//  LoopKit
//
//  Created by Darin Krauss on 5/11/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation

public protocol AnalyticsService: Service {

    func recordAnalyticsEvent(_ name: String, withProperties properties: [AnyHashable: Any]?, outOfSession: Bool)

    func recordIdentify(_ property: String, value: String)
}
