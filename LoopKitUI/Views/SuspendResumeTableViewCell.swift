//
//  SuspendResumeTableViewCell.swift
//  LoopKitUI
//
//  Created by Pete Schwamb on 11/16/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import LoopKit

public class SuspendResumeTableViewCell: TextButtonTableViewCell {
    
    public enum Action {
        case suspend
        case resume
    }
    
    public var shownAction: Action = .suspend {
        didSet {
            switch shownAction {
            case .suspend:
                textLabel?.text = LocalizedString("Suspend Delivery", comment: "Title text for button to suspend insulin delivery")
            case .resume:
                textLabel?.text = LocalizedString("Resume Delivery", comment: "Title text for button to resume insulin delivery")
            }
        }
    }
    
    public var basalDeliveryState: PumpManagerStatus.BasalDeliveryState = .active {
        didSet {
            switch self.basalDeliveryState {
            case .active:
                self.isEnabled = true
                self.shownAction = .suspend
                self.isLoading = false
            case .suspending:
                self.isEnabled = false
                self.textLabel?.text = LocalizedString("Suspending", comment: "Title text for button when insulin delivery is in the process of being stopped")
                self.isLoading = true
            case .suspended:
                self.isEnabled = true
                self.shownAction = .resume
                self.isLoading = false
            case .resuming:
                self.isEnabled = false
                self.textLabel?.text = LocalizedString("Resuming", comment: "Title text for button when insulin delivery is in the process of being resumed")
                self.isLoading = true
            }
        }
    }
}

