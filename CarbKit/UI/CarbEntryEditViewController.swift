//
//  CarbEntryEditViewController.swift
//  CarbKit
//
//  Created by Nathan Racklyeft on 1/15/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit
import HealthKit


public final class CarbEntryEditViewController: UITableViewController, DatePickerTableViewCellDelegate, TextFieldTableViewCellDelegate {

    public var defaultAbsorptionTimes: CarbStore.DefaultAbsorptionTimes? {
        didSet {
            if originalCarbEntry == nil, let times = defaultAbsorptionTimes {
                absorptionTime = times.1
            }
        }
    }

    public var preferredUnit: HKUnit = HKUnit.gram()

    public var originalCarbEntry: CarbEntry? {
        didSet {
            if let entry = originalCarbEntry {
                quantity = entry.quantity
                date = entry.startDate
                foodType = entry.foodType
                absorptionTime = entry.absorptionTime
            }
        }
    }

    private var quantity: HKQuantity?

    private var date = Date()

    private var foodType: String?

    private var absorptionTime: TimeInterval?

    public var updatedCarbEntry: CarbEntry? {
        if let  quantity = quantity,
                let absorptionTime = absorptionTime
        {
            if let o = originalCarbEntry, o.quantity == quantity && o.startDate == date && o.foodType == foodType && o.absorptionTime == absorptionTime {
                return nil  // No changes were made
            }

            return NewCarbEntry(quantity: quantity, startDate: date, foodType: foodType, absorptionTime: absorptionTime)
        } else {
            return nil
        }
    }

    private var isSampleEditable: Bool {
        return originalCarbEntry?.createdByCurrentApp != false
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        tableView.estimatedRowHeight = 44

        if originalCarbEntry != nil {
            title = NSLocalizedString("carb-entry-title-edit", tableName: "CarbKit", value: "Edit Carb Entry", comment: "The title of the view controller to edit an existing carb entry")
        } else {
            title = NSLocalizedString("carb-entry-title-add", tableName: "CarbKit", value: "Add Carb Entry", comment: "The title of the view controller to create a new carb entry")
        }
    }

    @IBOutlet var segmentedControlInputAccessoryView: SegmentedControlInputAccessoryView!

    @IBOutlet weak var saveButtonItem: UIBarButtonItem!

    // MARK: - Table view data source

    private enum Row: Int {
        case value
        case date
        case absorptionTime
    }

    public override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Row(rawValue: indexPath.row)! {
        case .value:
            let cell = tableView.dequeueReusableCell(withIdentifier: DecimalTextFieldTableViewCell.className) as! DecimalTextFieldTableViewCell

            if let quantity = quantity {
                cell.number = NSNumber(value: quantity.doubleValue(for: preferredUnit) as Double)
            }
            cell.textField.isEnabled = isSampleEditable
            cell.unitLabel.text = String(describing: preferredUnit)
            cell.delegate = self

            if originalCarbEntry == nil {
                cell.textField.becomeFirstResponder()
            }

            return cell
        case .date:
            let cell = tableView.dequeueReusableCell(withIdentifier: DatePickerTableViewCell.className) as! DatePickerTableViewCell

            cell.date = date
            cell.datePicker.isEnabled = isSampleEditable
            cell.delegate = self

            return cell
        case .absorptionTime:
            let cell = tableView.dequeueReusableCell(withIdentifier: AbsorptionTimeTextFieldTableViewCell.className) as! AbsorptionTimeTextFieldTableViewCell

            if let absorptionTime = absorptionTime {
                cell.number = NSNumber(value: absorptionTime.minutes as Double)
            }

            if let times = defaultAbsorptionTimes {
                cell.segmentValues = [times.fast.minutes, times.medium.minutes, times.slow.minutes]
            }
            cell.segmentedControlInputAccessoryView = segmentedControlInputAccessoryView
            cell.delegate = self

            return cell
        }
    }

    // MARK: - UITableViewDelegate

    public override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {

        tableView.endEditing(false)
        tableView.beginUpdates()
        return indexPath
    }

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.endUpdates()
        tableView.deselectRow(at: indexPath, animated: true)
    }

    // MARK: - Navigation

    public override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        self.tableView.endEditing(true)

        guard let sender = sender as? UIBarButtonItem, sender === saveButtonItem else {
            quantity = nil
            return
        }
    }

    // MARK: - DatePickerTableViewCellDelegate

    func datePickerTableViewCellDidUpdateDate(_ cell: DatePickerTableViewCell) {
        date = cell.date as Date
    }

    // MARK: - TextFieldTableViewCellDelegate

    func textFieldTableViewCellDidUpdateText(_ cell: DecimalTextFieldTableViewCell) {
        switch Row(rawValue: (tableView.indexPath(for: cell)?.row ?? -1)) {
        case .value?:
            if let number = cell.number {
                quantity = HKQuantity(unit: preferredUnit, doubleValue: number.doubleValue)
            } else {
                quantity = nil
            }
        case .absorptionTime?:
            if let number = cell.number {
                absorptionTime = TimeInterval(minutes: number.doubleValue)
            } else {
                absorptionTime = nil
            }
        default:
            break
        }
    }
}
