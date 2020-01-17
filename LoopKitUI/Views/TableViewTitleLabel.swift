//
//  TableViewTitleLabel.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-01-17.
//  Copyright © 2020 Tidepool Project. All rights reserved.
//

import UIKit

public class TableViewTitleLabel: UILabel {
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        font = UIFont.titleFontGroupedInset
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        font = UIFont.titleFontGroupedInset
    }
    
    override public func awakeFromNib() {
        super.awakeFromNib()
        font = UIFont.titleFontGroupedInset
    }
    
}
