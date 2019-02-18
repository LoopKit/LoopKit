//
//  CompletionNotifying.swift
//  LoopKitUI
//
//  Created by Pete Schwamb on 1/29/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation

public protocol CompletionDelegate: class {
    func completionNotifyingDidComplete(_ object: CompletionNotifying)
}

public protocol CompletionNotifying {
    var completionDelegate: CompletionDelegate? { set get }
}

