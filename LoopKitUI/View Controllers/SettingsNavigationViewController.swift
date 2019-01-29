//
//  SettingsNavigationViewController.swift
//  LoopKitUI
//
//  Created by Pete Schwamb on 1/29/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation

public class SettingsNavigationViewController: UINavigationController, CompletionNotifying {

    public weak var completionDelegate: CompletionDelegate?

    public func notifyComplete() {
        completionDelegate?.didComplete(viewController: self)
    }

}
