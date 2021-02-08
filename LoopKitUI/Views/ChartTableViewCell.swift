//
//  ChartTableViewCell.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/19/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit


public final class ChartTableViewCell: UITableViewCell {

    @IBOutlet weak var chartContentView: ChartContainerView!

    @IBOutlet weak var titleLabel: UILabel?

    @IBOutlet weak var subtitleLabel: UILabel?
   
    @IBOutlet weak var rightArrowHint: UIImageView? {
        didSet {
            rightArrowHint?.isHidden = !doesNavigate
        }
    }

    public var doesNavigate: Bool = true {
        didSet {
            rightArrowHint?.isHidden = !doesNavigate
        }
    }
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        doesNavigate = true
        chartContentView.chartGenerator = nil
    }

    public func reloadChart() {
        chartContentView.reloadChart()
    }
    
    public func setChartGenerator(generator: ((CGRect) -> UIView?)?) {
        chartContentView.chartGenerator = generator
    }
    
    public func setTitleLabelText(label: String?) {
        titleLabel?.text = label
    }
    
    public func removeTitleLabelText() {
        titleLabel?.text?.removeAll()
    }
    
    public func setSubtitleLabel(label: String?) {
        subtitleLabel?.text = label
    }
    
    public func removeSubtitleLabelText() {
        subtitleLabel?.text?.removeAll()
    }
    
    public func setTitleTextColor(color: UIColor) {
        titleLabel?.textColor = color
    }
    
    public func setSubtitleTextColor(color: UIColor) {
        subtitleLabel?.textColor = color
    }
    
    public func setAlpha(alpha: CGFloat) {
        titleLabel?.alpha = alpha
        subtitleLabel?.alpha = alpha
    }
}
