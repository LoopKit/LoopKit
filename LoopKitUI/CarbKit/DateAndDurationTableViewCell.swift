//
//  DateAndDurationTableViewCell.swift
//  LoopKitUI
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit

public class DateAndDurationTableViewCell: DatePickerTableViewCell {

    public weak var delegate: DatePickerTableViewCellDelegate?

    @IBOutlet public weak var titleLabel: UILabel!

    @IBOutlet public weak var dateLabel: UILabel! {
        didSet {
            // Setting this color in code because the nib isn't being applied correctly
            dateLabel.textColor = .secondaryLabel
        }
    }

    private lazy var durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()

        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short

        return formatter
    }()

    public override func updateDateLabel() {
        switch datePicker.datePickerMode {
        case .countDownTimer:
            dateLabel.text = durationFormatter.string(from: duration)
        case .date:
            dateLabel.text = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
        case .dateAndTime:
            dateLabel.text = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short)
        case .time:
            dateLabel.text = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .medium)
        @unknown default:
            break // Do nothing
        }
    }

    public override func dateChanged(_ sender: UIDatePicker) {
        super.dateChanged(sender)

        delegate?.datePickerTableViewCellDidUpdateDate(self)
    }
}
