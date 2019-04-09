//
//  BasalScheduleEntryTableViewCell.swift
//  LoopKitUI
//
//  Created by Pete Schwamb on 2/23/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit

protocol BasalScheduleEntryTableViewCellDelegate: class {
    func basalScheduleEntryTableViewCellDidUpdate(_ cell: BasalScheduleEntryTableViewCell)
    func isBasalScheduleEntryTableViewCellValid(_ cell: BasalScheduleEntryTableViewCell) -> Bool
}

private enum Component: Int, CaseIterable {
    case time = 0
    case value
}

class BasalScheduleEntryTableViewCell: UITableViewCell {

    @IBOutlet private weak var picker: UIPickerView!

    @IBOutlet private weak var pickerHeightConstraint: NSLayoutConstraint!

    private var pickerExpandedHeight: CGFloat = 0

    @IBOutlet private weak var dateLabel: UILabel!

    @IBOutlet private weak var valueLabel: UILabel!

    public weak var delegate: BasalScheduleEntryTableViewCellDelegate?

    public var basalRates: [Double] = [] {
        didSet {
            updateValuePicker(with: value)
        }
    }

    private let basalRateUnits = HKUnit.internationalUnitsPerHour

    public var minimumTimeInterval: TimeInterval = .hours(0.5)

    public var minimumStartTime: TimeInterval = .hours(0) {
        didSet {
            picker.reloadComponent(Component.time.rawValue)
            updateStartTimeSelection()
        }
    }
    public var maximumStartTime: TimeInterval = .hours(23.5) {
        didSet {
            picker.reloadComponent(Component.time.rawValue)
        }
    }

    public var timeZone: TimeZone! {
        didSet {
            dateFormatter.timeZone = timeZone
            var calendar = Calendar.current
            calendar.timeZone = timeZone
            startOfDay = calendar.startOfDay(for: Date())
        }
    }

    private lazy var startOfDay = Calendar.current.startOfDay(for: Date())

    var startTime: TimeInterval = 0 {
        didSet {
            updateStartTimeSelection()
            updateDateLabel()
        }
    }

    var selectedStartTime: TimeInterval {
        let row = picker.selectedRow(inComponent: Component.time.rawValue)
        return startTimeForTimeComponent(row: row)
    }

    var value: Double? = nil {
        didSet {
            updateValuePicker(with: value)
            updateValueLabel()
        }
    }

    var isPickerHidden: Bool {
        get {
            return picker.isHidden
        }
        set {
            picker.isHidden = newValue
            pickerHeightConstraint.constant = newValue ? 0 : pickerExpandedHeight

            if !newValue {
                updateValuePicker(with: value)
            }
        }
    }

    var isReadOnly = false

    override func awakeFromNib() {
        super.awakeFromNib()

        pickerExpandedHeight = pickerHeightConstraint.constant

        setSelected(true, animated: false)
        updateDateLabel()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        if selected && !isReadOnly {
            isPickerHidden.toggle()
        }
    }

    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short

        return dateFormatter
    }()

    lazy var valueQuantityFormatter: QuantityFormatter = {
        let formatter = QuantityFormatter()
        return formatter
    }()

    private func startTimeForTimeComponent(row: Int) -> TimeInterval {
        return minimumStartTime + minimumTimeInterval * TimeInterval(row)
    }

    private func stringForStartTime(_ time: TimeInterval) -> String {
        let date = startOfDay.addingTimeInterval(time)
        return dateFormatter.string(from: date)
    }

    func updateDateLabel() {
        dateLabel.text = stringForStartTime(startTime)
    }

    func validate() {
        if delegate?.isBasalScheduleEntryTableViewCellValid(self) == false {
            valueLabel.textColor = .invalid
        } else {
            valueLabel.textColor = .darkText
        }
    }

    func updateValueFromPicker() {
        value = basalRates[picker.selectedRow(inComponent: Component.value.rawValue)]
        updateValueLabel()
    }

    private func updateStartTimeSelection() {
        let row = Int(round((startTime - minimumStartTime) / minimumTimeInterval))
        if row >= 0 && row < pickerView(picker, numberOfRowsInComponent: Component.time.rawValue) {
            picker.selectRow(row, inComponent: Component.time.rawValue, animated: true)
        }
    }

    func updateValuePicker(with newValue: Double?) {
        guard let value = newValue, !basalRates.isEmpty else {
            return
        }
        let selectedIndex: Int
        if let row = basalRates.firstIndex(of: value) {
            selectedIndex = row
        } else {
            selectedIndex = basalRates.enumerated().filter({$0.element <= value}).max(by: { $0.1 < $1.1 })?.offset ?? 0
        }
        picker.selectRow(selectedIndex, inComponent: Component.value.rawValue, animated: true)
    }

    func updateValueLabel() {
        guard let value = value else {
            return
        }
        validate()
        let quantity = HKQuantity(unit: basalRateUnits, doubleValue: value)
        valueLabel.text = valueQuantityFormatter.string(from: quantity, for: basalRateUnits)
    }
}


extension BasalScheduleEntryTableViewCell: UIPickerViewDelegate {

    func pickerView(_ pickerView: UIPickerView,
                    didSelectRow row: Int,
                    inComponent component: Int) {
        switch Component(rawValue: component)! {
        case .time:
            startTime = selectedStartTime
        case .value:
            updateValueFromPicker()
        }

        delegate?.basalScheduleEntryTableViewCellDidUpdate(self)
    }

    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        let metrics = UIFontMetrics(forTextStyle: .body)
        return metrics.scaledValue(for: 32)
    }

    func pickerView(_ pickerView: UIPickerView,
                    titleForRow row: Int,
                    forComponent component: Int) -> String? {

        switch Component(rawValue: component)! {
        case .time:
            let time = startTimeForTimeComponent(row: row)
            return stringForStartTime(time)
        case .value:
            let quantity = HKQuantity(unit: basalRateUnits, doubleValue: basalRates[row])
            return valueQuantityFormatter.string(from: quantity, for: basalRateUnits)
        }
    }
}

extension BasalScheduleEntryTableViewCell: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return Component.allCases.count
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch Component(rawValue: component)! {
        case .time:
            return Int(round((maximumStartTime - minimumStartTime) / minimumTimeInterval) + 1)
        case .value:
            return basalRates.count
        }
    }
}

/// UITableViewController extensions to aid working with DatePickerTableViewCell
extension BasalScheduleEntryTableViewCellDelegate where Self: UITableViewController {
    func hideBasalScheduleEntryCells(excluding indexPath: IndexPath? = nil) {
        for case let cell as BasalScheduleEntryTableViewCell in tableView.visibleCells where tableView.indexPath(for: cell) != indexPath && cell.isPickerHidden == false {
            cell.isPickerHidden = true
        }
    }
}
