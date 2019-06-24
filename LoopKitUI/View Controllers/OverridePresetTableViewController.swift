//
//  OverridePresetTableViewController.swift
//  Loop
//
//  Created by Michael Pangburn on 1/2/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import UIKit
import HealthKit
import LoopKit


public protocol OverridePresetTableViewControllerDelegate: AnyObject {
    func overridePresetTableViewControllerDidUpdatePresets(_ vc: OverridePresetTableViewController)
}


public final class OverridePresetTableViewController: UITableViewController {

    let glucoseUnit: HKUnit

    public var presets: [TemporaryScheduleOverridePreset] {
        didSet {
            delegate?.overridePresetTableViewControllerDidUpdatePresets(self)
            if presets.isEmpty {
                if isViewLoaded, tableView.isEditing {
                    endEditing()
                }
                editButton.isEnabled = false
            } else {
                editButton.isEnabled = true
            }
        }
    }

    public weak var delegate: OverridePresetTableViewControllerDelegate?

    public init(glucoseUnit: HKUnit, presets: [TemporaryScheduleOverridePreset]) {
        self.glucoseUnit = glucoseUnit
        self.presets = presets
        super.init(style: .plain)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var saveButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addNewPreset))
    private lazy var editButton = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(beginEditing))
    private lazy var doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(endEditing))

    public override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("Override Presets", comment: "The title text for the override presets screen")
        navigationItem.rightBarButtonItems = [saveButton, editButton]
        tableView.register(SettingsTableViewCell.self, forCellReuseIdentifier: SettingsTableViewCell.className)

        if presets.isEmpty {
            editButton.isEnabled = false
        }
    }

    @objc private func addNewPreset() {
        let addVC = AddEditOverrideTableViewController(glucoseUnit: glucoseUnit)
        addVC.inputMode = .newPreset
        addVC.delegate = self

        let navigationWrapper = UINavigationController(rootViewController: addVC)
        present(navigationWrapper, animated: true)
    }

    @objc private func beginEditing() {
        tableView.setEditing(true, animated: true)
        saveButton.isEnabled = false
        navigationItem.setRightBarButtonItems([saveButton, doneButton], animated: true)
    }

    @objc private func endEditing() {
        tableView.setEditing(false, animated: true)
        saveButton.isEnabled = true
        navigationItem.setRightBarButtonItems([saveButton, editButton], animated: true)
    }

    public override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return presets.count
    }

    private let percentageFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumIntegerDigits = 1
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private lazy var quantityFormatter: QuantityFormatter = {
        let quantityFormatter = QuantityFormatter()
        quantityFormatter.setPreferredNumberFormatter(for: glucoseUnit)
        return quantityFormatter
    }()

    private lazy var glucoseNumberFormatter = quantityFormatter.numberFormatter

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath) as! SettingsTableViewCell
        let preset = presets[indexPath.row]
        cell.textLabel?.text = String(format: NSLocalizedString("%1$@ %2$@", comment: "The format for an override preset cell. (1: symbol)(2: name)"), preset.symbol, preset.name)
        if let insulinNeedsScaleFactor = preset.settings.insulinNeedsScaleFactor,
            let percentageString = percentageFormatter.string(from: insulinNeedsScaleFactor * 100) {
            cell.detailTextLabel?.text = String(format: NSLocalizedString("%@%% of normal insulin", comment: "The format for an insulin needs percentage."), percentageString)
        } else if let targetRange = preset.settings.targetRange,
            let minTarget = glucoseNumberFormatter.string(from: targetRange.minValue),
            let maxTarget = glucoseNumberFormatter.string(from: targetRange.maxValue) {
            cell.detailTextLabel?.text = String(format: NSLocalizedString("%1$@ – %2$@ %3$@", comment: "The format for a glucose target range. (1: min target)(2: max target)(3: glucose unit)"), minTarget, maxTarget, quantityFormatter.string(from: glucoseUnit))
        }

        return cell
    }

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let preset = presets[indexPath.row]
        let editVC = AddEditOverrideTableViewController(glucoseUnit: glucoseUnit)
        editVC.inputMode = .editPreset(preset)
        editVC.delegate = self
        show(editVC, sender: tableView.cellForRow(at: indexPath))
    }

    public override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let movedPreset = presets.remove(at: sourceIndexPath.row)
        presets.insert(movedPreset, at: destinationIndexPath.row)
    }

    public override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            presets.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
}

extension OverridePresetTableViewController: AddEditOverrideTableViewControllerDelegate {
    public func addEditOverrideTableViewController(_ vc: AddEditOverrideTableViewController, didSavePreset preset: TemporaryScheduleOverridePreset) {
        if let selectedIndexPath = tableView.indexPathForSelectedRow {
            presets[selectedIndexPath.row] = preset
            tableView.reloadRows(at: [selectedIndexPath], with: .automatic)
        } else {
            let nextIndexPath = IndexPath(row: presets.endIndex, section: 0)
            presets.append(preset)
            tableView.insertRows(at: [nextIndexPath], with: .automatic)
        }
    }
}
