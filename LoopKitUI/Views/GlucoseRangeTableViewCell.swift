//
//  GlucoseRangeTableViewCell.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/13/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit

protocol GlucoseRangeTableViewCellDelegate: class {
    func glucoseRangeTableViewCellDidUpdate(_ cell: GlucoseRangeTableViewCell)
}

class GlucoseRangeTableViewCell: UITableViewCell {

    public enum Component: Int, CaseIterable {
        case time = 0
        case minValue
        case separator
        case maxValue
        case units

        var placeholderString: String? {
            switch self {
            case .minValue:
                return LocalizedString("min", comment: "Placeholder for minimum value in glucose range")
            case .maxValue:
                return LocalizedString("max", comment: "Placeholder for maximum value in glucose range")
            default:
                return nil
            }
        }
    }

    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet open weak var picker: UIPickerView!
    @IBOutlet open weak var pickerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var minValueTextField: UITextField! {
        didSet {
            // Setting this color in code because the nib isn't being applied correctly
            if #available(iOSApplicationExtension 13.0, *) {
                minValueTextField.textColor = .label
            }
        }
    }
    @IBOutlet weak var separatorLabel: UILabel! {
        didSet {
            // Setting this color in code because the nib isn't being applied correctly
            if #available(iOSApplicationExtension 13.0, *) {
                separatorLabel.textColor = .secondaryLabel
            }
        }
    }
    @IBOutlet weak var maxValueTextField: UITextField! {
        didSet {
            // Setting this color in code because the nib isn't being applied correctly
            if #available(iOSApplicationExtension 13.0, *) {
                maxValueTextField.textColor = .label
            }
        }
    }
    @IBOutlet weak var unitLabel: UILabel! {
        didSet {
            // Setting this color in code because the nib isn't being applied correctly
            if #available(iOSApplicationExtension 13.0, *) {
                unitLabel.textColor = .secondaryLabel
            }
        }
    }

    private var pickerExpandedHeight: CGFloat = 0

    public var minimumTimeInterval: TimeInterval = .hours(0.5)

    public weak var delegate: GlucoseRangeTableViewCellDelegate?

    var allowTimeSelection: Bool = true

    var minValue: Double? {
        didSet {
            guard let value = minValue else {
                minValueTextField.text = nil
                return
            }
            minValueTextField.text = valueNumberFormatter.string(from: value)
        }
    }

    var maxValue: Double? {
        didSet {
            guard let value = maxValue else {
                maxValueTextField.text = nil
                return
            }
            maxValueTextField.text = valueNumberFormatter.string(from: value)
        }
    }

    public var allowedValues: [Double] = [] {
        didSet {
            picker.reloadAllComponents()
            selectPickerValues()
        }
    }

    private var allowedMaxValues: [Double] {
        guard let minValue = minValue else {
            return allowedValues
        }
        return allowedValues.filter( { $0 >= minValue })
    }

    private var allowedMinValues: [Double] {
        guard let maxValue = maxValue else {
            return allowedValues
        }
        return allowedValues.filter( { $0 <= maxValue })
    }

    var unitString: String? {
        get {
            return unitLabel.text
        }
        set {
            unitLabel.text = newValue
        }
    }

    lazy var valueNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1

        return formatter
    }()

    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short

        return dateFormatter
    }()

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

    public var allowedTimeRange: ClosedRange<TimeInterval> = .hours(0)...(.hours(23.5)) {
        didSet {
            picker.reloadComponent(Component.time.rawValue)
            updateStartTimeSelection()
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
                selectPickerValues()
            }
        }
    }


    private func updateStartTimeSelection() {
        let row = Int(round((startTime - allowedTimeRange.lowerBound) / minimumTimeInterval))
        if row >= 0 && row < pickerView(picker, numberOfRowsInComponent: Component.time.rawValue) {
            picker.selectRow(row, inComponent: Component.time.rawValue, animated: true)
        }
    }

    fileprivate func selectPickerValue(for component: Component, with selectedValue: Double?, allowedValues: [Double]) {
        guard !allowedValues.isEmpty else {
            return
        }
        let selectedIndex: Int
        if let value = selectedValue {
            if let row = allowedValues.firstIndex(of: value) {
                selectedIndex = row
            } else {
                // Select next highest value
                selectedIndex = allowedValues.enumerated().filter({$0.element >= value}).min(by: { $0.1 < $1.1 })?.offset ?? 0
            }
        } else {
            selectedIndex = allowedValues.count
        }
        picker.selectRow(selectedIndex, inComponent: component.rawValue, animated: false)
    }

    fileprivate func selectPickerValues() {
        selectPickerValue(for: .minValue, with: minValue, allowedValues: allowedMinValues)
        selectPickerValue(for: .maxValue, with: maxValue, allowedValues: allowedMaxValues)
    }

    fileprivate func updateMinValueFromPicker() {
        let index = picker.selectedRow(inComponent: Component.minValue.rawValue)
        let value: Double?
        if index >= 0 && index < allowedMinValues.count {
            value = allowedMinValues[index]
        } else {
            value = nil
        }
        minValue = value
    }

    fileprivate func updateMaxValueFromPicker() {
        let index = picker.selectedRow(inComponent: Component.maxValue.rawValue)
        let value: Double?
        if index >= 0 && index < allowedMaxValues.count {
            value = allowedMaxValues[index]
        } else {
            value = nil
        }
        maxValue = value
    }

    func updateDateLabel() {
        dateLabel.text = stringForStartTime(startTime)
    }

    private func startTimeForTimeComponent(row: Int) -> TimeInterval {
        return allowedTimeRange.lowerBound + minimumTimeInterval * TimeInterval(row)
    }

    private func stringForStartTime(_ time: TimeInterval) -> String {
        let date = startOfDay.addingTimeInterval(time)
        return dateFormatter.string(from: date)
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        pickerExpandedHeight = pickerHeightConstraint.constant

        setSelected(true, animated: false)
        updateDateLabel()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        if selected {
            isPickerHidden.toggle()
        }
    }
}

extension GlucoseRangeTableViewCell: UIPickerViewDelegate {

    func pickerView(_ pickerView: UIPickerView,
                    didSelectRow row: Int,
                    inComponent componentRaw: Int) {
        let component = Component(rawValue: componentRaw)!
        switch component {
        case .time:
            startTime = selectedStartTime
        case .minValue:
            updateMinValueFromPicker()
            picker.reloadComponent(Component.minValue.rawValue)
            picker.reloadComponent(Component.maxValue.rawValue)
            selectPickerValues()
        case .maxValue:
            updateMaxValueFromPicker()
            picker.reloadComponent(Component.minValue.rawValue)
            picker.reloadComponent(Component.maxValue.rawValue)
            selectPickerValues()
        default:
            break
        }

        delegate?.glucoseRangeTableViewCellDidUpdate(self)
    }

    func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
        return [33,16,4,16,24][component] / 100.0 * picker.frame.width
    }

    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        let metrics = UIFontMetrics(forTextStyle: .body)
        return metrics.scaledValue(for: 32)
    }

    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {

        let title: String?
        let component = Component(rawValue: component)!
        var attributes: [NSAttributedString.Key : Any]? = nil

        switch component {
        case .time:
            let time = startTimeForTimeComponent(row: row)
            title = stringForStartTime(time)
        case .minValue:
            if row >= allowedMinValues.count {
                title = component.placeholderString
                attributes = [.foregroundColor: UIColor.lightGray]
            } else {
                title = valueNumberFormatter.string(from: allowedMinValues[row])
            }
        case .maxValue:
            if row >= allowedMaxValues.count {
                title = component.placeholderString
                attributes = [.foregroundColor: UIColor.lightGray]
            } else {
                title = valueNumberFormatter.string(from: allowedMaxValues[row])
            }
        case .separator:
            title = LocalizedString("-", comment: "Separator between min and max glucose values")
        case .units:
            title = unitString
        }
        if let title = title {
            return NSAttributedString(string: title, attributes: attributes)
        } else {
            return nil
        }
    }
}

extension GlucoseRangeTableViewCell: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return Component.allCases.count
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch Component(rawValue: component)! {
        case .time:
            if allowTimeSelection {
                return Int(round((allowedTimeRange.upperBound - allowedTimeRange.lowerBound) / minimumTimeInterval) + 1)
            } else {
                return 0
            }
        case .minValue:
            return allowedMinValues.count + (minValue != nil ? 0 : 1)
        case .maxValue:
            return allowedMaxValues.count + (maxValue != nil ? 0 : 1)
        case .units, .separator:
            return 1
        }

    }
}

/// UITableViewController extensions to aid working with DatePickerTableViewCell
extension GlucoseRangeTableViewCellDelegate where Self: UITableViewController {
    func hideGlucoseRangeCells(excluding indexPath: IndexPath? = nil) {
        for case let cell as GlucoseRangeTableViewCell in tableView.visibleCells where tableView.indexPath(for: cell) != indexPath && cell.isPickerHidden == false {
            cell.isPickerHidden = true
        }
    }
}
