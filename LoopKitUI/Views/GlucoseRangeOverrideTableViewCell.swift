//
//  GlucoseRangeOverrideTableViewCell.swift
//  LoopKit
//
//  Created by Nate Racklyeft on 7/13/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit

class GlucoseRangeOverrideTableViewCell: GlucoseRangeTableViewCell {

    // MARK: Outlets
    @IBOutlet weak var iconImageView: UIImageView!

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        self.allowTimeSelection = false
    }
}
