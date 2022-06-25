//
//  SetupUIResult.swift
//  LoopKitUI
//
//  Created by Darin Krauss on 1/21/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

public enum SetupUIResult<UserInteractionRequired, CreatedAndOnboarded> {
    case userInteractionRequired(UserInteractionRequired)
    case createdAndOnboarded(CreatedAndOnboarded)
}
