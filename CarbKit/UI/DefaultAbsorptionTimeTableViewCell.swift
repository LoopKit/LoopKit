//
//  DefaultAbsorptionTimeTableViewCell.swift
//  LoopKit
//
//  Created by Michael Pangburn on 6/2/17.
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import UIKit


protocol DefaultAbsorptionTimeTableViewCellDelegate: class {
    func defaultAbsorptionTimeTableViewCellDidUpdateTime(_ cell: DefaultAbsorptionTimeTableViewCell)
}


class DefaultAbsorptionTimeTableViewCell: UITableViewCell {

    weak var delegate: DefaultAbsorptionTimeTableViewCellDelegate?
    
    var time: TimeInterval {
        get {
            return timePicker.countDownDuration
        }
        set {
            timePicker.countDownDuration = newValue
            timeChanged(timePicker)
        }
    }
    
    @IBOutlet weak var absorptionSpeedLabel: UILabel!
    
    @IBOutlet weak var timeLabel: UILabel!
    
    @IBOutlet weak var timePicker: UIDatePicker!
    
    @IBOutlet weak var timePickerHeightConstraint: NSLayoutConstraint!
    
    private var timePickerExpandedHeight: CGFloat = 0
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        timePickerExpandedHeight = timePickerHeightConstraint.constant
        
        setSelected(true, animated: false)
        timeChanged(timePicker)
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        if selected && timePicker.isEnabled {
            let closed = timePicker.isHidden
            
            timePicker.isHidden = !closed
            timePickerHeightConstraint.constant = closed ? timePickerExpandedHeight : 0
        }
    }
    
    @IBAction func timeChanged(_ sender: UIDatePicker) {
        timeLabel.text = "\(Int(time.minutes)) min"
        
        delegate?.defaultAbsorptionTimeTableViewCellDidUpdateTime(self)
    }
}
