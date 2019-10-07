//
//  MockService+UI.swift
//  MockKitUI
//
//  Created by Darin Krauss on 5/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit
import LoopKitUI
import MockKit

extension MockService: ServiceUI {

    public static func setupViewController() -> (UIViewController & ServiceSetupNotifying & CompletionNotifying)? {
        return ServiceViewController(rootViewController: MockServiceTableViewController(service: MockService(), for: .create))
    }

    public func settingsViewController() -> (UIViewController & ServiceSetupNotifying & CompletionNotifying) {
      return ServiceViewController(rootViewController: MockServiceTableViewController(service: self, for: .update))
    }
    
}
