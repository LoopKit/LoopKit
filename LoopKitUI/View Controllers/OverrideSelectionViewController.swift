//
//  OverrideSelectionViewController.swift
//  Loop
//
//  Created by Michael Pangburn on 1/2/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import UIKit
import HealthKit
import LoopKit


public protocol OverrideSelectionViewControllerDelegate: AnyObject {
    func overrideSelectionViewController(_ vc: OverrideSelectionViewController, didConfirmOverride override: TemporaryScheduleOverride)
    func overrideSelectionViewController(_ vc: OverrideSelectionViewController, didCancelOverride override: TemporaryScheduleOverride)
}

public final class OverrideSelectionViewController: UICollectionViewController, IdentifiableClass {

    public var glucoseUnit: HKUnit!

    public var scheduledOverride: TemporaryScheduleOverride?

    public var presets: [TemporaryScheduleOverridePreset] = []

    public weak var delegate: OverrideSelectionViewControllerDelegate?

    public override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("Temporary Override", comment: "The title for the override selection screen")
        collectionView?.backgroundColor = .groupTableViewBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        setupLongPressGestureRecognizer()
    }

    private func setupLongPressGestureRecognizer() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        collectionView.addGestureRecognizer(longPress)
    }

    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard
            recognizer.state == .began,
            case let touchPoint = recognizer.location(in: collectionView),
            let indexPath = collectionView.indexPathForItem(at: touchPoint),
            case .preset(let preset) = cellContent(for: indexPath)
        else {
            return
        }

        collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .left)
        let customizePresetVC = AddEditOverrideTableViewController(glucoseUnit: glucoseUnit)
        customizePresetVC.inputMode = .customizePresetOverride(preset)
        customizePresetVC.delegate = self
        show(customizePresetVC, sender: nil)
    }

    @objc private func cancel() {
        dismiss(animated: true)
    }

    enum Section: Int, CaseIterable {
        case scheduledOverride = 0
        case presets
    }

    private var sections: [Section] {
        var sections = Section.allCases
        if scheduledOverride == nil {
            sections.remove(.scheduledOverride)
        }
        return sections
    }

    private func section(for sectionIndex: Int) -> Section {
        return sections[sectionIndex]
    }

    private enum CellContent {
        case scheduledOverride(TemporaryScheduleOverride)
        case preset(TemporaryScheduleOverridePreset)
        case customOverride
    }

    private func cellContent(for indexPath: IndexPath) -> CellContent {
        switch section(for: indexPath.section) {
        case .scheduledOverride:
            guard let scheduledOverride = scheduledOverride else {
                preconditionFailure("`sections` must contain `.scheduledOverride`")
            }
            return .scheduledOverride(scheduledOverride)
        case .presets:
            if presets.indices.contains(indexPath.row) {
                return .preset(presets[indexPath.row])
            } else {
                return .customOverride
            }
        }
    }

    public override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.count
    }

    public override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch self.section(for: section) {
        case .scheduledOverride:
            return 1
        case .presets:
            // +1 for custom override
            return presets.count + 1 
        }
    }

    public override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: OverrideSelectionHeaderView.className, for: indexPath) as! OverrideSelectionHeaderView
            switch section(for: indexPath.section) {
            case .scheduledOverride:
                header.titleLabel.text = NSLocalizedString("SCHEDULED OVERRIDE", comment: "The section header text for a scheduled override")
            case .presets:
                header.titleLabel.text = NSLocalizedString("PRESETS", comment: "The section header text override presets")
            }
            return header
        case UICollectionView.elementKindSectionFooter:
            let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: OverrideSelectionFooterView.className, for: indexPath) as! OverrideSelectionFooterView
            footer.textLabel.text = NSLocalizedString("Override presets can be set up under the 'Configuration' section of the settings screen.", comment: "Text directing the user to configure override presets")
            return footer
        default:
            fatalError("Unexpected supplementary element kind \(kind)")
        }
    }

    public override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: OverridePresetCollectionViewCell.className, for: indexPath) as! OverridePresetCollectionViewCell

        let customSymbol = "⋯"
        let customName = NSLocalizedString("Custom", comment: "The text for a custom override")

        switch cellContent(for: indexPath) {
        case .scheduledOverride(let override):
            if case .preset(let preset) = override.context {
                cell.symbolLabel.text = preset.symbol
                cell.nameLabel.text = preset.name
            } else {
                cell.symbolLabel.text = customSymbol
                cell.nameLabel.text = customName
            }
            cell.startTimeLabel.text = DateFormatter.localizedString(from: override.startDate, dateStyle: .none, timeStyle: .short)
        case .preset(let preset):
            cell.symbolLabel.text = preset.symbol
            cell.startTimeLabel.text?.removeAll()
            cell.nameLabel.text = preset.name
        case .customOverride:
            cell.symbolLabel.text = customSymbol
            cell.startTimeLabel.text?.removeAll()
            cell.nameLabel.text = customName
        }

        return cell
    }

    public override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch cellContent(for: indexPath) {
        case .scheduledOverride(let override):
            let editOverrideVC = AddEditOverrideTableViewController(glucoseUnit: glucoseUnit)
            editOverrideVC.inputMode = .editOverride(override)
            editOverrideVC.customDismissalMode = .dismissModal
            editOverrideVC.delegate = self
            show(editOverrideVC, sender: collectionView.cellForItem(at: indexPath))
        case .preset(let preset):
            let override = preset.createOverride()
            delegate?.overrideSelectionViewController(self, didConfirmOverride: override)
            dismiss(animated: true)
        case .customOverride:
            let customOverrideVC = AddEditOverrideTableViewController(glucoseUnit: glucoseUnit)
            customOverrideVC.inputMode = .customOverride
            customOverrideVC.delegate = self
            show(customOverrideVC, sender: collectionView.cellForItem(at: indexPath))
        }
    }
}

extension OverrideSelectionViewController: UICollectionViewDelegateFlowLayout {
    private var sectionInsets: UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16)
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        guard presets.isEmpty else { return .zero }
        return CGSize(width: collectionView.frame.width, height: 50)
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let itemsPerRow = 3
        let paddingSpace = sectionInsets.left * CGFloat(itemsPerRow + 1)
        let availableWidth = view.frame.width - paddingSpace
        let widthPerItem = availableWidth / CGFloat(itemsPerRow)

        return CGSize(width: widthPerItem, height: widthPerItem)
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
        return sectionInsets
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int
    ) -> CGFloat {
        return sectionInsets.left
    }
}

extension OverrideSelectionViewController: AddEditOverrideTableViewControllerDelegate {
    public func addEditOverrideTableViewController(_ vc: AddEditOverrideTableViewController, didSaveOverride override: TemporaryScheduleOverride) {
        delegate?.overrideSelectionViewController(self, didConfirmOverride: override)
    }

    public func addEditOverrideTableViewController(_ vc: AddEditOverrideTableViewController, didCancelOverride override: TemporaryScheduleOverride) {
        delegate?.overrideSelectionViewController(self, didCancelOverride: override)
    }
}

private extension Array where Element: Equatable {
    mutating func remove(_ element: Element) {
        if let index = self.firstIndex(of: element) {
            remove(at: index)
        }
    }
}
