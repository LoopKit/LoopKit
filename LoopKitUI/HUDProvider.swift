//
//  HUDProvider.swift
//  LoopKitUI
//
//  Created by Pete Schwamb on 1/29/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation

public enum HUDTapAction {
    case presentViewController(UIViewController & CompletionNotifying)
    case openAppURL(URL)
}

public protocol HUDProvider {
    var managerIdentifier: String { get }

    typealias HUDViewsRawState = [String: Any]

    // Creates the initial views to be shown in Loop HUD.
    func createHUDViews() -> [BaseHUDView]

    // Returns the action that should be taken when the view is tapped
    func didTapOnHUDView(_ view: BaseHUDView) -> HUDTapAction?

    // The current, serializable state of the HUD views
    var hudViewsRawState: HUDViewsRawState { get }

    func hudDidAppear()
}

