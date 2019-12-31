//
//  LoadingTableViewCell.swift
//  LoopKitUI
//
//  Created by Pete Schwamb on 10/24/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation
import UIKit

open class LoadingTableViewCell: UITableViewCell {

    public var isLoading = false {
        didSet {
            if isLoading {
                let indicator = UIActivityIndicatorView(style: .default)
                accessoryView = indicator
                indicator.startAnimating()
            } else {
                accessoryView = nil
            }
            loadingStatusChanged()
        }
    }
    
    open func loadingStatusChanged() {}
}
