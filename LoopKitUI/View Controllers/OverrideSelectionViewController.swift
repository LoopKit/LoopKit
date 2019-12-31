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
    func overrideSelectionViewController(_ vc: OverrideSelectionViewController, didUpdatePresets presets: [TemporaryScheduleOverridePreset])
    func overrideSelectionViewController(_ vc: OverrideSelectionViewController, didConfirmOverride override: TemporaryScheduleOverride)
    func overrideSelectionViewController(_ vc: OverrideSelectionViewController, didCancelOverride override: TemporaryScheduleOverride)
}

public final class OverrideSelectionViewController: UICollectionViewController, IdentifiableClass {

    public var glucoseUnit: HKUnit!

    public var scheduledOverride: TemporaryScheduleOverride?

    public var presets: [TemporaryScheduleOverridePreset] = [] {
        didSet {
            delegate?.overrideSelectionViewController(self, didUpdatePresets: presets)
        }
    }

    public weak var delegate: OverrideSelectionViewControllerDelegate?

    private lazy var saveButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addNewPreset))
    private lazy var editButton = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(beginEditing))
    private lazy var doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(endEditing))
    private lazy var cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))

    public override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("Temporary Override", comment: "The title for the override selection screen")
        collectionView?.backgroundColor = .groupTableViewBackground
        navigationItem.rightBarButtonItems = [saveButton, editButton]
        navigationItem.leftBarButtonItem = cancelButton
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

    private var presetSection: Int {
        sections.firstIndex(of: .presets)!
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

    private func indexPathOfCustomOverride() -> IndexPath {
        let section = sections.firstIndex(of: .presets)!
        let row = self.collectionView(collectionView, numberOfItemsInSection: section) - 1
        return IndexPath(row: row, section: section)
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
            footer.textLabel.text = NSLocalizedString("Tap '+' to create a new override preset.", comment: "Text directing the user to configure their first override preset")
            return footer
        default:
            fatalError("Unexpected supplementary element kind \(kind)")
        }
    }

    private lazy var quantityFormatter: QuantityFormatter = {
        let quantityFormatter = QuantityFormatter()
        quantityFormatter.setPreferredNumberFormatter(for: glucoseUnit)
        return quantityFormatter
    }()

    private lazy var glucoseNumberFormatter = quantityFormatter.numberFormatter

    private lazy var durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    public override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let customSymbol = "⋯"
        let customName = NSLocalizedString("Custom", comment: "The text for a custom override")

        switch cellContent(for: indexPath) {
        case .scheduledOverride(let override):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: OverridePresetCollectionViewCell.className, for: indexPath) as! OverridePresetCollectionViewCell
            cell.delegate = self
            if case .preset(let preset) = override.context {
                cell.symbolLabel.text = preset.symbol
                cell.nameLabel.text = preset.name
            } else {
                cell.symbolLabel.text = customSymbol
                cell.nameLabel.text = customName
            }

            cell.startTimeLabel.text = DateFormatter.localizedString(from: override.startDate, dateStyle: .none, timeStyle: .short)
            configure(cell, with: override.settings, duration: override.duration)
            cell.scheduleButton.isHidden = true
            if isEditingPresets {
                cell.applyOverlayToFade(animated: false)
            }

            return cell
        case .preset(let preset):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: OverridePresetCollectionViewCell.className, for: indexPath) as! OverridePresetCollectionViewCell
            cell.delegate = self
            cell.symbolLabel.text = preset.symbol
            cell.nameLabel.text = preset.name
            configure(cell, with: preset.settings, duration: preset.duration)
            if isEditingPresets {
                cell.configureForEditing(animated: false)
            }

            return cell
        case .customOverride:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CustomOverrideCollectionViewCell.className, for: indexPath) as! CustomOverrideCollectionViewCell
            cell.titleLabel.text = customName
            if isEditingPresets {
                cell.applyOverlayToFade(animated: false)
            }

            return cell
        }
    }

    private func configure(_ cell: OverridePresetCollectionViewCell, with settings: TemporaryScheduleOverrideSettings, duration: TemporaryScheduleOverride.Duration) {
        if let targetRange = settings.targetRange {
            cell.targetRangeLabel.text = makeTargetRangeText(from: targetRange)
        } else {
            cell.targetRangeLabel.isHidden = true
        }

        if let insulinNeedsScaleFactor = settings.insulinNeedsScaleFactor {
            cell.insulinNeedsBar.progress = insulinNeedsScaleFactor
        } else {
            cell.insulinNeedsBar.isHidden = true
        }

        switch duration {
        case .finite(let interval):
            cell.durationLabel.text = durationFormatter.string(from: interval)
        case .indefinite:
            cell.durationLabel.text = "∞"
        }
    }

    private func makeTargetRangeText(from targetRange: ClosedRange<HKQuantity>) -> String {
        guard
            let minTarget = glucoseNumberFormatter.string(from: targetRange.lowerBound.doubleValue(for: glucoseUnit)),
            let maxTarget = glucoseNumberFormatter.string(from: targetRange.upperBound.doubleValue(for: glucoseUnit))
        else {
            return ""
        }

        return String(format: NSLocalizedString("%1$@ – %2$@ %3$@", comment: "The format for a glucose target range. (1: min target)(2: max target)(3: glucose unit)"), minTarget, maxTarget, quantityFormatter.string(from: glucoseUnit))
    }

    public override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isEditingPresets {
            switch cellContent(for: indexPath) {
            case .scheduledOverride, .customOverride:
                break
            case .preset(let preset):
                let editVC = AddEditOverrideTableViewController(glucoseUnit: glucoseUnit)
                editVC.inputMode = .editPreset(preset)
                editVC.delegate = self
                show(editVC, sender: collectionView.cellForItem(at: indexPath))
            }
        } else {
            switch cellContent(for: indexPath) {
            case .scheduledOverride(let override):
                let editOverrideVC = AddEditOverrideTableViewController(glucoseUnit: glucoseUnit)
                editOverrideVC.inputMode = .editOverride(override)
                editOverrideVC.customDismissalMode = .dismissModal
                editOverrideVC.delegate = self
                show(editOverrideVC, sender: collectionView.cellForItem(at: indexPath))
            case .preset(let preset):
                let override = preset.createOverride(enactTrigger: .local)
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

    @objc private func addNewPreset() {
        let addVC = AddEditOverrideTableViewController(glucoseUnit: glucoseUnit)
        addVC.inputMode = .newPreset
        addVC.delegate = self

        let navigationWrapper = UINavigationController(rootViewController: addVC)
        present(navigationWrapper, animated: true)
    }

    private var isEditingPresets = false {
        didSet {
            saveButton.isEnabled = !isEditingPresets
            cancelButton.isEnabled = !isEditingPresets
        }
    }

    @objc private func beginEditing() {
        isEditingPresets = true
        navigationItem.setRightBarButtonItems([saveButton, doneButton], animated: true)
        configureCellsForEditingChanged()

        if let scheduledOverrideSection = sections.firstIndex(of: .scheduledOverride) {
            let scheduledOverrideIndexPath = IndexPath(row: 0, section: scheduledOverrideSection)
            guard let scheduledOverrideCell = collectionView.cellForItem(at: scheduledOverrideIndexPath) as? OverridePresetCollectionViewCell else {
                return
            }

            scheduledOverrideCell.applyOverlayToFade(animated: true)
        }

        if let customOverrideCell = collectionView.cellForItem(at: indexPathOfCustomOverride()) as? CustomOverrideCollectionViewCell {
            customOverrideCell.applyOverlayToFade(animated: true)
        }
    }

    @objc private func endEditing() {
        isEditingPresets = false
        navigationItem.setRightBarButtonItems([saveButton, editButton], animated: true)
        configureCellsForEditingChanged()

        if let scheduledOverrideSection = sections.firstIndex(of: .scheduledOverride) {
            let scheduledOverrideIndexPath = IndexPath(row: 0, section: scheduledOverrideSection)
            guard let scheduledOverrideCell = collectionView.cellForItem(at: scheduledOverrideIndexPath) as? OverridePresetCollectionViewCell else {
                return
            }

            scheduledOverrideCell.removeOverlay(animated: true)
        }

        if let customOverrideCell = collectionView.cellForItem(at: indexPathOfCustomOverride()) as? CustomOverrideCollectionViewCell {
            customOverrideCell.removeOverlay(animated: true)
        }
    }

    private func configureCellsForEditingChanged() {
        for indexPath in collectionView.indexPathsForVisibleItems where indexPath.section == presetSection {
            if let cell = collectionView.cellForItem(at: indexPath) as? OverridePresetCollectionViewCell {
                if isEditingPresets {
                    cell.configureForEditing(animated: true)
                } else {
                    cell.configureForStandard(animated: true)
                }
            }
        }
    }

    public override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        if !isEditingPresets {
            return true
        }

        switch cellContent(for: indexPath) {
        case .scheduledOverride, .customOverride:
            return false
        case .preset:
            return true
        }
    }

    public override func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        isEditingPresets
            && indexPath.section == presetSection
            && indexPath != indexPathOfCustomOverride()

    }

    public override func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let movedPreset = presets.remove(at: sourceIndexPath.row)
        presets.insert(movedPreset, at: destinationIndexPath.row)
    }

    public override func collectionView(_ collectionView: UICollectionView, targetIndexPathForMoveFromItemAt originalIndexPath: IndexPath, toProposedIndexPath proposedIndexPath: IndexPath) -> IndexPath {
        guard proposedIndexPath.section == sections.firstIndex(of: .presets) else {
            return originalIndexPath
        }

        return proposedIndexPath == indexPathOfCustomOverride()
            ? originalIndexPath
            : proposedIndexPath

    }
}

extension OverrideSelectionViewController: UICollectionViewDelegateFlowLayout {
    private var sectionInsets: UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 12, bottom: 12, right: 12)
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
        let paddingSpace = sectionInsets.left * 2
        let width = view.frame.width - paddingSpace
        let height: CGFloat
        switch cellContent(for: indexPath) {
        case .scheduledOverride, .preset:
            height = 76
        case .customOverride:
            height = 52
        }

        return CGSize(width: width, height: height)
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
    public func addEditOverrideTableViewController(_ vc: AddEditOverrideTableViewController, didSavePreset preset: TemporaryScheduleOverridePreset) {
        if let selectedIndexPath = collectionView.indexPathsForSelectedItems?.first {
            presets[selectedIndexPath.row] = preset
            collectionView.reloadItems(at: [selectedIndexPath])
            collectionView.deselectItem(at: selectedIndexPath, animated: true)
        } else {
            presets.append(preset)
            collectionView.insertItems(at: [IndexPath(row: presets.endIndex - 1, section: presetSection)])
            delegate?.overrideSelectionViewController(self, didUpdatePresets: presets)
        }
    }

    public func addEditOverrideTableViewController(_ vc: AddEditOverrideTableViewController, didSaveOverride override: TemporaryScheduleOverride) {
        delegate?.overrideSelectionViewController(self, didConfirmOverride: override)
    }

    public func addEditOverrideTableViewController(_ vc: AddEditOverrideTableViewController, didCancelOverride override: TemporaryScheduleOverride) {
        delegate?.overrideSelectionViewController(self, didCancelOverride: override)
    }
}

extension OverrideSelectionViewController: OverridePresetCollectionViewCellDelegate {
    func overridePresetCollectionViewCellDidScheduleOverride(_ cell: OverridePresetCollectionViewCell) {
        guard
            let indexPath = collectionView.indexPath(for: cell),
            case .preset(let preset) = cellContent(for: indexPath)
        else {
            return
        }

        let customizePresetVC = AddEditOverrideTableViewController(glucoseUnit: glucoseUnit)
        customizePresetVC.inputMode = .customizePresetOverride(preset)
        customizePresetVC.delegate = self
        show(customizePresetVC, sender: nil)
    }

    func overridePresetCollectionViewCellDidPerformFirstDeletionStep(_ cell: OverridePresetCollectionViewCell) {
        for case let visibleCell as OverridePresetCollectionViewCell in collectionView.visibleCells
            where visibleCell !== cell && visibleCell.isShowingFinalDeleteConfirmation
        {
            visibleCell.configureForEditing(animated: true)
        }
    }

    func overridePresetCollectionViewCellDidDeletePreset(_ cell: OverridePresetCollectionViewCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else {
            return
        }

        presets.remove(at: indexPath.row)
        collectionView.deleteItems(at: [indexPath])
    }
}

private extension Array where Element: Equatable {
    mutating func remove(_ element: Element) {
        if let index = self.firstIndex(of: element) {
            remove(at: index)
        }
    }
}
