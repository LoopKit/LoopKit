//
//  OverridePresetCollectionViewCell.swift
//  Loop
//
//  Created by Michael Pangburn on 1/2/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import UIKit


protocol OverridePresetCollectionViewCellDelegate: AnyObject {
    func overridePresetCollectionViewCellDidScheduleOverride(_ cell: OverridePresetCollectionViewCell)
    func overridePresetCollectionViewCellDidPerformFirstDeletionStep(_ cell: OverridePresetCollectionViewCell)
    func overridePresetCollectionViewCellDidDeletePreset(_ cell: OverridePresetCollectionViewCell)
}

final class OverridePresetCollectionViewCell: UICollectionViewCell, IdentifiableClass {
    @IBOutlet weak var symbolLabel: UILabel!

    @IBOutlet weak var startTimeLabel: UILabel! {
        didSet {
            startTimeLabel.text?.removeAll()
        }
    }

    @IBOutlet weak var nameLabel: UILabel!

    @IBOutlet weak var targetRangeLabel: UILabel! {
        didSet {
            targetRangeLabel.text?.removeAll()
        }
    }

    @IBOutlet weak var insulinNeedsBar: SegmentedGaugeBarView! {
        didSet {
            if #available(iOSApplicationExtension 13.0, *) {
                insulinNeedsBar.backgroundColor = .systemGray6
            } else {
                insulinNeedsBar.backgroundColor = .white
            }
        }
    }

    @IBOutlet private weak var durationStackView: UIStackView!
    @IBOutlet weak var durationLabel: UILabel!

    @IBOutlet weak var scheduleButton: UIButton!

    @IBOutlet private weak var editingIndicator: UIImageView! {
        didSet {
            editingIndicator.alpha = 0
        }
    }

    @IBOutlet private weak var deleteButton: UIButton! {
        didSet {
            deleteButton.layer.cornerRadius = 4
        }
    }

    @IBOutlet private weak var deleteButtonWidthConstraint: NSLayoutConstraint! {
        didSet {
            deleteButtonWidthConstraint.constant = 0
        }
    }

    weak var delegate: OverridePresetCollectionViewCellDelegate?

    private lazy var overlayDimmerView: UIView = {
        let view = UIView()
        if #available(iOSApplicationExtension 13.0, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }
        view.alpha = 0
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

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

        scheduleButton.addTarget(self, action: #selector(scheduleButtonTapped), for: .touchUpInside)
        addSubview(overlayDimmerView)
        NSLayoutConstraint.activate([
            overlayDimmerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlayDimmerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlayDimmerView.topAnchor.constraint(equalTo: topAnchor),
            overlayDimmerView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    override func prepareForReuse() {
        startTimeLabel.text?.removeAll()
        targetRangeLabel.isHidden = false
        insulinNeedsBar.isHidden = false
        configureForStandard(animated: false)
        removeOverlay(animated: false)
    }

    func configureForEditing(animated: Bool) {
        func makeVisualChanges() {
            durationStackView.alpha = 0
            scheduleButton.alpha = 0
            editingIndicator.alpha = 1
            deleteButtonWidthConstraint.constant = 32
            if #available(iOSApplicationExtension 13.0, *) {
                deleteButton.setImage(UIImage(systemName: "xmark")!, for: .normal)
            }
            deleteButton.setTitle(nil, for: .normal)
        }

        if animated {
            UIView.animate(withDuration: 0.3, animations: {
                makeVisualChanges()
                self.layoutIfNeeded()
            })
        } else {
            makeVisualChanges()
        }

        isShowingFinalDeleteConfirmation = false
    }

    func configureForStandard(animated: Bool) {
        func makeVisualChanges() {
            durationStackView.alpha = 1
            scheduleButton.alpha = 1
            editingIndicator.alpha = 0
            deleteButtonWidthConstraint.constant = 0
            if #available(iOSApplicationExtension 13.0, *) {
                deleteButton.setImage(UIImage(systemName: "xmark")!, for: .normal)
            }
            deleteButton.setTitle(nil, for: .normal)
        }

        if animated {
            UIView.animate(withDuration: 0.3, animations: {
                makeVisualChanges()
                self.layoutIfNeeded()
            })
        } else {
            makeVisualChanges()
        }

        isShowingFinalDeleteConfirmation = false
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

    @objc private func scheduleButtonTapped() {
        delegate?.overridePresetCollectionViewCellDidScheduleOverride(self)
    }

    private(set) var isShowingFinalDeleteConfirmation = false

    @IBAction private func deleteButtonTapped(_ sender: UIButton) {
        if isShowingFinalDeleteConfirmation {
            delegate?.overridePresetCollectionViewCellDidDeletePreset(self)
        } else {
            UIView.animate(withDuration: 0.3, animations: {
                self.deleteButton.setImage(nil, for: .normal)
                self.deleteButton.setTitle("Delete", for: .normal)
                self.deleteButtonWidthConstraint.constant = 72
                self.layoutIfNeeded()
            })

            isShowingFinalDeleteConfirmation = true
            delegate?.overridePresetCollectionViewCellDidPerformFirstDeletionStep(self)
        }
    }
}
