//
//  ChartTableViewCell.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/19/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import SwiftUI
import UIKit


public final class ChartTableViewCell: UITableViewCell {

    @IBOutlet public weak var supplementalChartContentView: ChartContainerView?
    
    @IBOutlet weak var chartContentView: ChartContainerView!

    @IBOutlet weak var mainStackView: UIStackView!
    
    @IBOutlet weak var titleStackView: UIStackView?
    
    @IBOutlet weak var titleLabel: UILabel?

    @IBOutlet weak var subtitleLabel: UILabel?
    
    var footerView: UIView?
   
    @IBOutlet weak var rightArrowHint: UIImageView? {
        didSet {
            rightArrowHint?.isHidden = !doesNavigate
        }
    }
    
    public override func awakeFromNib() {
        titleStackView?.layoutMargins = UIEdgeInsets(top: 11, left: 16, bottom: 0, right: 16)
        titleStackView?.isLayoutMarginsRelativeArrangement = true
    }

    public var doesNavigate: Bool = true {
        didSet {
            rightArrowHint?.isHidden = !doesNavigate
        }
    }
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        doesNavigate = true
        supplementalChartContentView?.isHidden = true
        supplementalChartContentView?.chartGenerator = nil
        chartContentView.chartGenerator = nil
        removeFooterView()
    }

    public func reloadChart() {
        supplementalChartContentView?.reloadChart()
        chartContentView.reloadChart()
    }
    
    public func setChartGenerator(generator: ((CGRect) -> UIView?)?) {
        chartContentView.chartGenerator = generator
    }
    
    public func setSupplementalChartGenerator(generator: ((CGRect) -> UIView?)?) {
        supplementalChartContentView?.chartGenerator = generator
        supplementalChartContentView?.isHidden = generator == nil
    }
    
    public func setTitleLabelText(label: String?) {
        titleLabel?.text = label
        titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
    }
    
    public func setTitleLabelAccessibilityIdentifier(_ value: String) {
        titleLabel?.accessibilityIdentifier = 
            "chartTitleText_\(value)_\(ChartsManager.xAxisAccessibilityIDs?.count ?? -1)"
    }
    
    public func setTitleLabelText(label: NSAttributedString?) {
        titleLabel?.attributedText = label
    }
    
    public func removeTitleLabelText() {
        titleLabel?.text?.removeAll()
        titleLabel?.attributedText = NSAttributedString(string: "")
    }
    
    public func setSubtitleLabel(label: NSAttributedString?) {
        subtitleLabel?.attributedText = label
    }
    
    public func removeSubtitleLabelText() {
        subtitleLabel?.text?.removeAll()
        subtitleLabel?.attributedText = NSAttributedString(string: "")
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
        footerView?.alpha = alpha
    }
    
    public func removeFooterView() {
        self.footerView?.removeFromSuperview()
        self.footerView = nil
    }
    
    public func setFooterView(content: (() -> some View)?) {
        removeFooterView()
        
        if let content = content?() {
            guard !(content is EmptyView), let rootView = UIHostingController(rootView: content).view else {
                return
            }
            
            self.footerView = rootView
            self.mainStackView.addArrangedSubview(rootView)
        }
    }
}
