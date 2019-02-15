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
    
    public var shownAction: Action {
        switch basalDeliveryState {
        case .active, .suspending:
            return .suspend
        case .suspended, .resuming:
            return .resume
        }
    }

    private func updateTextLabel() {
        switch self.basalDeliveryState {
        case .active:
            textLabel?.text = LocalizedString("Suspend Delivery", comment: "Title text for button to suspend insulin delivery")
        case .suspending:
            self.textLabel?.text = LocalizedString("Suspending", comment: "Title text for button when insulin delivery is in the process of being stopped")
        case .suspended:
            textLabel?.text = LocalizedString("Resume Delivery", comment: "Title text for button to resume insulin delivery")
        case .resuming:
            self.textLabel?.text = LocalizedString("Resuming", comment: "Title text for button when insulin delivery is in the process of being resumed")
        }
    }

    private func updateLoadingState() {
        self.isLoading = {
            switch self.basalDeliveryState {
            case .suspending, .resuming:
                return true
            default:
                return false
            }
        }()
        self.isEnabled = !self.isLoading
    }
    
    public var basalDeliveryState: PumpManagerStatus.BasalDeliveryState = .active {
        didSet {
            updateTextLabel()
            updateLoadingState()
        }
    }
}

