//
//  DateAndDurationSteppableTableViewCell.swift
//  LoopKitUI
//
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import UIKit

public class DateAndDurationSteppableTableViewCell: DatePickerTableViewCell {

    public weak var delegate: DatePickerTableViewCellDelegate?

    @IBOutlet public weak var titleLabel: UILabel!

    @IBOutlet public weak var dateLabel: UILabel! {
        didSet {
            dateLabel.textColor = .secondaryLabel
        }
    }
    
    @IBOutlet weak var incrementButton: UIButton!

    @IBOutlet weak var decrementButton: UIButton! 
    
    public var timeStepSize: TimeInterval = .minutes(15)
    
    public override var isDatePickerHidden: Bool {
        didSet {
            dateLabel.textColor = isDatePickerHidden ? .secondaryLabel : window?.tintColor
        }
    }
        
    private lazy var durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()

        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short

        return formatter
    }()
    
    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.doesRelativeDateFormatting = true
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short
    
        return dateFormatter
    }()

    public override func updateDateLabel() {
        if dateFormatter.doesRelativeDateFormatting {
            dateFormatter.dateStyle = Calendar.current.isDateInToday(date) ? .none : .short
        }
        
        switch datePicker.datePickerMode {
        case .countDownTimer:
            dateLabel.text = durationFormatter.string(from: duration)
        case .date, .dateAndTime, .time:
            dateLabel.text = dateFormatter.string(from: date)
        @unknown default:
            break // Do nothing
        }
        
        updateButtonState()
    }

    public override func dateChanged(_ sender: UIDatePicker) {
        super.dateChanged(sender)

        delegate?.datePickerTableViewCellDidUpdateDate(self)
    }
    
    @IBAction func incrementTime(_ sender: UIButton) {
        date = date.addingTimeInterval(timeStepSize)
    }
    
    @IBAction func decrementTime(_ sender: UIButton) {
        date = date.addingTimeInterval(-timeStepSize)
    }
        
    private func updateButtonState() {
        // since the picker sets the seconds to 0, compare in the same way
        if let maximumDate = datePicker.maximumDate {
            let order = Calendar.current.compare(date, to: maximumDate, toGranularity: .minute)
            incrementButton.isEnabled = order == .orderedAscending
        }
        
        if let minimumDate = datePicker.minimumDate {
            let order = Calendar.current.compare(date, to: minimumDate, toGranularity: .minute)
            decrementButton.isEnabled = order == .orderedDescending
        }
    }
}
