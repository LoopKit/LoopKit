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
        case indeterminantProgress
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
                    let animator = UIViewPropertyAnimator(duration: duration, curve: .linear)
                    animator.addAnimations {
                        self.progressView.setProgress(1, animated: true)
                    }
                    animator.startAnimation()
                    self.progressAnimator = animator
                } else {
                    progressView.progress = 1
                }
            }
        }
    }

    @IBInspectable var animationDuration: Double = 0.5


    private func viewUsedInState(_ state: State) -> UIView? {
        switch state {
        case .hidden:
            return nil
        case .indeterminantProgress:
            return activityIndicatorView
        case .timedProgress:
            return progressView
        case .completed:
            return completionImageView
        }
    }

    private func animate(from oldState: State, to newState: State) {
        guard oldState != newState else {
            return
        }

        if let animator = self.animator, animator.isRunning {
            animator.stopAnimation(true)
        }

        // Figure out which views are not used in any ongoing animations
        var unusedViews: Set = [activityIndicatorView, progressView, completionImageView]

        let viewToHide = viewUsedInState(oldState)
        unusedViews.remove(viewToHide)

        let viewToShow = viewUsedInState(newState)
        unusedViews.remove(viewToShow)

        for view in unusedViews {
            view?.alpha = 0
        }

        if case .timedProgress = oldState {
            progressAnimator?.stopAnimation(true)
        }

        let animator = UIViewPropertyAnimator(duration: animationDuration, dampingRatio: 0.5)
        animator.addAnimations {

            viewToHide?.alpha = 0
            viewToShow?.alpha = 1

            switch oldState {
            case .completed:
                self.completionImageView.transform = CGAffineTransform(scaleX: 0.001, y: 0.001)
            default:
                break
            }


            switch newState {
            case .indeterminantProgress:
                self.activityIndicatorView.startAnimating()
            case .completed:
                self.completionImageView.transform = CGAffineTransform.identity
            default:
                break
            }
        }
        animator.addCompletion { (position) in
            if self.state != .indeterminantProgress {
                self.activityIndicatorView.stopAnimating()
            }
        }
        animator.startAnimation()
        self.animator = animator
    }

    private var progressAnimator: UIViewPropertyAnimator?

    private var animator: UIViewPropertyAnimator?

    private let activityIndicatorView = UIActivityIndicatorView(style: .default)

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
        completionImageView.transform = CGAffineTransform(scaleX: 0.001, y: 0.001)
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
    
