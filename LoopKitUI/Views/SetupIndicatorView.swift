//
//  SetupIndicatorView.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit

@IBDesignable
public class SetupIndicatorView: UIView {

    public enum State {
        case hidden
        case loading
        case completed
    }

    public var state: State = .hidden {
        didSet {
            switch (oldValue, state) {
            case (.hidden, .hidden), (.loading, .loading), (.completed, .completed):
                break
            case (.hidden, .loading):
                break
            case (.hidden, .completed):
                break
            case (.completed, .hidden):
                break
            case (.completed, .loading):
                break
            case (.loading, .hidden):
                break
            case (.loading, .completed):
                break
            }

            animate(from: oldValue, to: state)
        }
    }

    @IBInspectable var animationDuration: Double = 0.5

    private func animate(from oldState: State, to newState: State) {
        guard oldState != newState else {
            return
        }

        if let animator = self.animator, animator.isRunning {
            switch oldState {
            case .hidden:
                break
            case .loading, .completed:
                completionImageView.alpha = 1
                animator.isReversed = !animator.isReversed
                return
            }
        }

        let isActivityIndicatorViewRunning = (newState == .loading)
        let isCompletionHidden = (newState != .completed)
        let wasHidden = (oldState == .hidden)

        completionImageView.alpha = wasHidden && isCompletionHidden ? 0 : 1

        let animator = UIViewPropertyAnimator(duration: animationDuration, dampingRatio: 0.5)
        animator.addAnimations {
            if isActivityIndicatorViewRunning {
                self.activityIndicatorView.alpha = 1
                self.activityIndicatorView.startAnimating()
            } else {
                self.activityIndicatorView.alpha = 0
            }

            if isCompletionHidden {
                self.completionImageView.transform = CGAffineTransform(scaleX: 0.001, y: 0.001)
                self.completionImageView.alpha = 0
            } else {
                self.completionImageView.transform = CGAffineTransform.identity
                self.completionImageView.alpha = 1
            }
        }
        animator.addCompletion { (position) in
            if self.state != .loading {
                self.activityIndicatorView.stopAnimating()
            }
        }
        animator.startAnimation()
        self.animator = animator
    }

    private var animator: UIViewPropertyAnimator?

    private let activityIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: .gray)

    private(set) var completionImageView: UIImageView!

    override init(frame: CGRect) {
        super.init(frame: frame)

        setUp()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        setUp()
    }

    private func setUp() {
        let image = UIImage(named: "Checkmark", in: Bundle(for: type(of: self)), compatibleWith: traitCollection)!
        completionImageView = UIImageView(image: image)
        completionImageView.alpha = 0
        completionImageView.translatesAutoresizingMaskIntoConstraints = false

        activityIndicatorView.alpha = 0
        activityIndicatorView.hidesWhenStopped = true
        activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(activityIndicatorView)
        addSubview(completionImageView)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: image.size.width),
            heightAnchor.constraint(equalToConstant: image.size.height),
            completionImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            completionImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            activityIndicatorView.centerXAnchor.constraint(equalTo: centerXAnchor),
            activityIndicatorView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    override public var intrinsicContentSize: CGSize {
        return completionImageView?.image?.size ?? activityIndicatorView.intrinsicContentSize
    }
}
