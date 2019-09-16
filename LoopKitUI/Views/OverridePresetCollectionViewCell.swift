//
//  OverridePresetCollectionViewCell.swift
//  Loop
//
//  Created by Michael Pangburn on 1/2/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import UIKit


final class OverridePresetCollectionViewCell: UICollectionViewCell, IdentifiableClass {
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var startTimeLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        let selectedBackgroundView = UIView()
        self.selectedBackgroundView = selectedBackgroundView

        if #available(iOSApplicationExtension 13.0, iOS 13.0, *) {
            selectedBackgroundView.backgroundColor = .tertiarySystemFill

            backgroundColor = .secondarySystemGroupedBackground
            layer.cornerCurve = .continuous
        } else {
            selectedBackgroundView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)

            backgroundColor = .white
        }

        layer.cornerRadius = 16
    }
}
