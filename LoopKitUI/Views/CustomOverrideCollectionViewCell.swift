//
//  CustomOverrideCollectionViewCell.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 11/5/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import UIKit


final class CustomOverrideCollectionViewCell: UICollectionViewCell, IdentifiableClass {
    @IBOutlet weak var titleLabel: UILabel!

    private lazy var overlayDimmerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.alpha = 0
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override func awakeFromNib() {
        super.awakeFromNib()

        let selectedBackgroundView = UIView()
        self.selectedBackgroundView = selectedBackgroundView

        selectedBackgroundView.backgroundColor = .tertiarySystemFill

        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerCurve = .continuous

        layer.cornerRadius = 16

        addSubview(overlayDimmerView)
        NSLayoutConstraint.activate([
            overlayDimmerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlayDimmerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlayDimmerView.topAnchor.constraint(equalTo: topAnchor),
            overlayDimmerView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    override func prepareForReuse() {
        removeOverlay(animated: false)
    }

    func applyOverlayToFade(animated: Bool) {
        if animated {
            UIView.animate(withDuration: 0.3, animations: {
                self.overlayDimmerView.alpha = 0.5
            })
        } else {
            self.overlayDimmerView.alpha = 0.5
        }
    }

    func removeOverlay(animated: Bool) {
        if animated {
            UIView.animate(withDuration: 0.3, animations: {
                self.overlayDimmerView.alpha = 0
            })
        } else {
            self.overlayDimmerView.alpha = 0
        }
    }
}
