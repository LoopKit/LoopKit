//
//  TableViewTitleLabel.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-01-17.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import UIKit

public class TableViewTitleLabel: UILabel {
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        initFont()
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        initFont()
    }
    
    override public func awakeFromNib() {
        super.awakeFromNib()
        initFont()
    }
    
    public func initFont() {
        font = UIFont.titleFontGroupedInset
        self.adjustsFontForContentSizeCategory = true
    }
    
}
