//
//  SetupIndicatorView.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit

@IBDesignable
public class SetupIndicatorView: UIView {

    public enum State: Equatable {
        case hidden
        case loading
        case timedProgress(finishTime: CFTimeInterval)
        case completed
    }

    public var state: State = .hidden {
        didSet {
            animate(from: oldValue, to: state)
            
            if case let .timedProgress(finishTime) = state {
                let duration = finishTime - CACurrentMediaTime()
                progressView.progress = 0
                if duration > 0 {
                    UIView.animate(withDuration: duration, delay: 0, options: [.curveLinear], animations: {
                        self.progressView.setProgress(1, animated: true)
                    }, completion: nil)
                } else {
                    progressView.progress = 1
                }
            }
        }
    }
    
    @IBInspectable var animationDuration: Double = 0.5

    private func animate(from oldState: State, to newState: State) {
        guard oldState != newState else {
            return
        }
        
        let isProgressViewRunning: Bool
        if case .timedProgress = newState {
            isProgressViewRunning = true
        } else {
            isProgressViewRunning = false
        }
        let isActivityIndicatorViewRunning = (newState == .loading)
        let isCompletionHidden = (newState != .completed)
        let wasHidden = (oldState == .hidden)
        
        if let animator = self.animator, animator.isRunning {
            switch oldState {
            case .hidden:
                break
            case .loading, .completed, .timedProgress:
                completionImageView.alpha = isCompletionHidden ? 0 : 1
                progressView.alpha = isProgressViewRunning ? 1 : 0
                animator.isReversed = !animator.isReversed
                return
            }
        }

        completionImageView.alpha = wasHidden && isCompletionHidden ? 0 : 1

        let animator = UIViewPropertyAnimator(duration: animationDuration, dampingRatio: 0.5)
        animator.addAnimations {
            if isActivityIndicatorViewRunning {
                self.activityIndicatorView.alpha = 1
                self.activityIndicatorView.startAnimating()
            } else {
                self.activityIndicatorView.alpha = 0
            }
            
            if isProgressViewRunning {
                self.progressView.alpha = 1
            } else {
                self.progressView.alpha = 0
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

    private let activityIndicatorView = UIActivityIndicatorView(style: .gray)

    private let progressView = UIProgressView(progressViewStyle: .default)

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

        progressView.alpha = 0
        progressView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(activityIndicatorView)
        addSubview(progressView)
        addSubview(completionImageView)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: image.size.height),
            completionImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            completionImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            activityIndicatorView.centerXAnchor.constraint(equalTo: centerXAnchor),
            activityIndicatorView.centerYAnchor.constraint(equalTo: centerYAnchor),
            progressView.centerXAnchor.constraint(equalTo: centerXAnchor),
            progressView.centerYAnchor.constraint(equalTo: centerYAnchor),
            progressView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            progressView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
        ])
    }
    
    override public var intrinsicContentSize: CGSize {
        return completionImageView?.image?.size ?? activityIndicatorView.intrinsicContentSize
    }
}
