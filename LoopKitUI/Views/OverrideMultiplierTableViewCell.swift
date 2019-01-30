//
//  OverrideMultiplierTableViewCell.swift
//  Loop
//
//  Created by Michael Pangburn on 1/2/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import UIKit


final class OverrideMultiplierTableViewCell: UITableViewCell {
    enum Factor: CaseIterable {
        case basalRate
        case insulinSensitivity
        case carbRatio
    }

    private let viewsByFactor = Factor.allCases.reduce(into: [:]) { views, factor in
        views[factor] = OverrideMultiplierView(frame: .zero)
    }

    private func view(for factor: Factor) -> OverrideMultiplierView {
        return viewsByFactor[factor]!
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    private func setup() {
        selectionStyle = .none
        setupMultiplierViews()
        setupLocalizedText()
    }

    private func setupMultiplierViews() {
        let multiplierViews: [UIView] = Factor.allCases.map(view(for:))

        for view in multiplierViews {
            view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(view)
        }

        for (left, right) in multiplierViews.adjacentPairs() {
            left.widthAnchor.constraint(equalTo: right.widthAnchor).isActive = true
        }

        let separatedMultiplierViews = Array(multiplierViews.interspersed(with: {
            let spacerView = UIView(frame: .zero)
            spacerView.backgroundColor = .tableViewSeparatorColor

            spacerView.translatesAutoresizingMaskIntoConstraints = false
            spacerView.widthAnchor.constraint(equalToConstant: 1).isActive = true
            self.contentView.addSubview(spacerView)

            return spacerView
        }))

        for view in separatedMultiplierViews {
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
                view.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor)
            ])
        }

        for (left, right) in separatedMultiplierViews.adjacentPairs() {
            left.rightAnchor.constraint(equalTo: right.leftAnchor).isActive = true
        }

        NSLayoutConstraint.activate([
            separatedMultiplierViews.first!.leftAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leftAnchor),
            separatedMultiplierViews.last!.rightAnchor.constraint(equalTo: contentView.layoutMarginsGuide.rightAnchor)
        ])
    }

    private func setupLocalizedText() {
        view(for: .basalRate).titleLabel.text = NSLocalizedString("Basal Rate", comment: "The text for the basal rate override multiplier")
        view(for: .basalRate).descriptionLabel.text = NSLocalizedString("of normal basal", comment: "The description text for the basal rate override multiplier")
        view(for: .insulinSensitivity).titleLabel.text = NSLocalizedString("Sensitivity", comment: "The text for the insulin sensitivity override multiplier")
        view(for: .insulinSensitivity).descriptionLabel.text = NSLocalizedString("normal sensitivity", comment: "The description text for the insulin sensitivity override multiplier")
        view(for: .carbRatio).titleLabel.text = NSLocalizedString("Carb Ratio", comment: "The text for the carb ratio override multiplier")
        view(for: .carbRatio).descriptionLabel.text = NSLocalizedString("normal carb ratio", comment: "The description text for the carb ratio override multiplier")
    }

    private let percentageFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumIntegerDigits = 1
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private let multiplierNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumIntegerDigits = 1
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    func setMultipliers(
        basalRate basalRateMultiplier: Double,
        insulinSensitivity insulinSensitivityMultiplier: Double,
        carbRatio carbRatioMultiplier: Double
    ) {
        guard
            let basalRateMultiplierText = percentageFormatter.string(from: basalRateMultiplier * 100),
            let insulinSensitivityMultiplierText = multiplierNumberFormatter.string(from: insulinSensitivityMultiplier),
            let carbRatioMultiplierText = multiplierNumberFormatter.string(from: carbRatioMultiplier)
        else {
            assertionFailure("Unable to produce multiplier strings using number formatter")
            return
        }

        let percentageFormat = NSLocalizedString("%@%%", comment: "The format string for a percentage value")
        view(for: .basalRate).multiplierLabel.text = String(format: percentageFormat, basalRateMultiplierText)

        let multiplierFormat = NSLocalizedString("%@x", comment: "The format string for a multiplicative factor")
        view(for: .insulinSensitivity).multiplierLabel.text = String(format: multiplierFormat, insulinSensitivityMultiplierText)
        view(for: .carbRatio).multiplierLabel.text = String(format: multiplierFormat, carbRatioMultiplierText)
    }
}

private extension Sequence {
    func interspersed(with separator: @escaping () -> Element) -> AnySequence<Element> {
        var iterator = makeIterator()
        var current = iterator.next()
        var shouldReturnSeparator = false
        return AnySequence {
            AnyIterator {
                if current == nil {
                    // iteration complete
                    return nil
                }

                defer { shouldReturnSeparator.toggle() }

                if shouldReturnSeparator {
                    return separator()
                } else {
                    defer { current = iterator.next() }
                    return current
                }
            }
        }
    }
}

private extension Collection {
    func adjacentPairs() -> Zip2Sequence<Self, SubSequence> {
        return zip(self, dropFirst())
    }
}

private extension UIColor {
    static let tableViewSeparatorColor = UITableView().separatorColor
}
