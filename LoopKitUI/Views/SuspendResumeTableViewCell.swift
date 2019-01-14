//
//  SuspendResumeTableViewCell.swift
//  LoopKitUI
//
//  Created by Pete Schwamb on 11/16/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import LoopKit

public protocol SuspendResumeTableViewCellDelegate: class {
    func suspendTapped()
    func resumeTapped()
}

public class SuspendResumeTableViewCell: TextButtonTableViewCell {
    
    enum Action {
        case suspend
        case resume
    }
    
    var action: Action = .suspend {
        didSet {
            switch action {
            case .suspend:
                textLabel?.text = LocalizedString("Suspend Delivery", comment: "Title text for button to suspend insulin delivery")
            case .resume:
                textLabel?.text = LocalizedString("Resume Delivery", comment: "Title text for button to resume insulin delivery")
            }
        }
    }
    
    public var basalDeliveryState: PumpManagerStatus.BasalDeliveryState = .none {
        didSet {
            switch self.basalDeliveryState {
            case .none:
                self.isEnabled = true
                self.action = .suspend
                self.isLoading = false
            case .suspending:
                self.isEnabled = false
                self.textLabel?.text = LocalizedString("Suspending", comment: "Title text for button when insulin delivery is in the process of being stopped")
                self.isLoading = true
            case .suspended:
                self.isEnabled = true
                self.action = .resume
                self.isLoading = false
            case .resuming:
                self.isEnabled = false
                self.textLabel?.text = LocalizedString("Resuming", comment: "Title text for button when insulin delivery is in the process of being resumed")
                self.isLoading = true
            }
        }
    }
    
    public weak var delegate: SuspendResumeTableViewCellDelegate?
    
    public func toggle() {
        switch action {
        case .resume:
            delegate?.resumeTapped()
        case .suspend:
            delegate?.suspendTapped()
        }
    }
}

extension SuspendResumeTableViewCell: PumpManagerStatusObserver {
    public func pumpManager(_ pumpManager: PumpManager, didUpdate status: PumpManagerStatus) {
        DispatchQueue.main.async {
            self.basalDeliveryState = status.basalDeliveryState
        }
    }
}
