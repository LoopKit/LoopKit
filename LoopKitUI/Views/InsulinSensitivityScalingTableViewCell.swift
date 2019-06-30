//
//  InsulinSensitivityScalingTableViewCell.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 3/22/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import UIKit


protocol InsulinSensitivityScalingTableViewCellDelegate: AnyObject {
    func insulinSensitivityScalingTableViewCellDidUpdateScaleFactor(_ cell: InsulinSensitivityScalingTableViewCell)
}


final class InsulinSensitivityScalingTableViewCell: UITableViewCell {

    private let allScaleFactorPercentages = Array(stride(from: 10, through: 200, by: 10))

    @IBOutlet private weak var titleLabel: UILabel!
    
    @IBOutlet private weak var valueLabel: UILabel!

    @IBOutlet weak var gaugeBar: SegmentedGaugeBarView! {
        didSet {
            gaugeBar.backgroundColor = .white
        }
    }

    @IBOutlet private weak var scaleFactorPicker: UIPickerView! {
        didSet {
            scaleFactorPicker.dataSource = self
            scaleFactorPicker.delegate = self
        }
    }

    @IBOutlet private weak var scaleFactorPickerHeightConstraint: NSLayoutConstraint! {
        didSet {
            pickerExpandedHeight = scaleFactorPickerHeightConstraint.constant
        }
    }

    private var pickerExpandedHeight: CGFloat = 0
    
    @IBOutlet private weak var footerLabel: UILabel!

    var isPickerHidden: Bool {
        get {
            return scaleFactorPicker.isHidden
        }
        set {
            scaleFactorPicker.isHidden = newValue
            scaleFactorPickerHeightConstraint.constant = newValue ? 0 : pickerExpandedHeight

            if !newValue {
                guard let selectedRow = allScaleFactorPercentages.index(of: selectedPercentage) else {
                    fatalError("selectedPercentage should always be validated against all possible scale factors")
                }
                scaleFactorPicker.selectRow(selectedRow, inComponent: 0, animated: false)
            }
        }
    }

    private var selectedPercentage = 100 {
        didSet {
            gaugeBar.progress = Double(self.selectedPercentage) / 100
            valueLabel.text = percentageString(from: selectedPercentage)
            updateFooterLabel()
            delegate?.insulinSensitivityScalingTableViewCellDidUpdateScaleFactor(self)
        }
    }

    var scaleFactor: Double {
        get {
            return Double(selectedPercentage) / 100
        }
        set {
            let percentage = Int(round(newValue * 100))
                .clamped(to: allScaleFactorPercentages.first!...allScaleFactorPercentages.last!)

            if allScaleFactorPercentages.contains(percentage) {
                selectedPercentage = percentage
            } else {
                // Truncate to nearest valid percentage
                selectedPercentage = allScaleFactorPercentages
                    .adjacentPairs()
                    .first(where: { lower, upper in
                        (lower..<upper).contains(percentage)
                    })?.0 ?? 100
            }
        }
    }

    weak var delegate: InsulinSensitivityScalingTableViewCellDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()

        titleLabel.text = NSLocalizedString("Overall Insulin Needs", comment: "The title text for the insulin sensitivity scaling setting")

        selectedPercentage = 100
        setSelected(true, animated: false)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        // Save and reassign the background color to avoid propagated transparency during the animation.
        let gaugeBarBackgroundColor = gaugeBar.backgroundColor
        super.setSelected(selected, animated: animated)

        if selected {
            gaugeBar.backgroundColor = gaugeBarBackgroundColor
            isPickerHidden.toggle()
        }
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        // Save and reassign the background color to avoid propagated transparency during the animation.
        let gaugeBarBackgroundColor = gaugeBar.backgroundColor
        super.setHighlighted(highlighted, animated: animated)

        if highlighted {
            gaugeBar.backgroundColor = gaugeBarBackgroundColor
        }
    }

    private func updateFooterLabel() {
        let footerText: String

        let delta = selectedPercentage - 100
        if delta < 0 {
            footerText = String(
                format: NSLocalizedString("Basal, bolus, and correction insulin dose amounts are decreased by %@%%.", comment: "Describes a percentage decrease in overall insulin needs"),
                String(abs(delta))
            )
        } else if delta > 0 {
            footerText = String(
                format: NSLocalizedString("Basal, bolus, and correction insulin dose amounts are increased by %@%%.", comment: "Describes a percentage increase in overall insulin needs"),
                String(delta)
            )
        } else {
            footerText = NSLocalizedString("Basal, bolus, and correction insulin dose amounts are unaffected.", comment: "Describes a lack of change in overall insulin needs")
        }

        footerLabel.text = footerText
    }

    private func percentageString(from percentage: Int) -> String {
        return String(format: NSLocalizedString("%@%%", comment: "Format string for percentage value"), String(percentage))
    }
}

extension InsulinSensitivityScalingTableViewCell: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return allScaleFactorPercentages.count
    }
}

extension InsulinSensitivityScalingTableViewCell: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return percentageString(from: allScaleFactorPercentages[row])
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedPercentage = allScaleFactorPercentages[row]
    }
}

extension InsulinSensitivityScalingTableViewCellDelegate where Self: UITableViewController {
    func collapseInsulinSensitivityScalingCells(excluding indexPath: IndexPath? = nil) {
        for case let cell as InsulinSensitivityScalingTableViewCell in tableView.visibleCells where tableView.indexPath(for: cell) != indexPath && !cell.isPickerHidden {
            cell.isPickerHidden = true
        }
    }
}
