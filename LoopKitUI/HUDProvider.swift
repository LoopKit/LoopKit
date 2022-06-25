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
    case setupNewPump
    case setupNewCGM
    case takeNoAction
}

public protocol HUDProvider: AnyObject  {
    var managerIdentifier: String { get }

    typealias HUDViewRawState = [String: Any]

    // Creates the initial view (typically reservoir volume) to be shown in Loop HUD.
    func createHUDView() -> BaseHUDView?

    // Returns the action that should be taken when the view is tapped
    func didTapOnHUDView(_ view: BaseHUDView, allowDebugFeatures: Bool) -> HUDTapAction?

    // The current, serializable state of the HUD views
    var hudViewRawState: HUDViewRawState { get }

    // This notifies the HUDProvider whether hud views are offscreen or
    // backgrounded. When not visible, updates should be deferred to better
    // inform the user when they are returning to the views. Showing
    // changed state via animations might be appropriate when becoming
    // visible. When not visible, the HUDProvider should limit work done to
    // save cpu resources while backgrounded.
    var visible: Bool { get set }
}

