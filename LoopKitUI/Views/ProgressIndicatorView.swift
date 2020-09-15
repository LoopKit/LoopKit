//
//  ProgressIndicatorView.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 3/2/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import Combine

public enum ProgressIndicatorState: Equatable {
    case hidden
    case indeterminantProgress
    case timedProgress(finishTime: CFTimeInterval)
    case completed
}

extension ProgressIndicatorState {
    
    var showProgressBar: Bool {
        if case .timedProgress = self {
            return true
        }
        return false
    }
    
    var showIndeterminantProgress: Bool {
        if case .indeterminantProgress = self {
            return true
        }
        return false
    }
    
    var showCompletion: Bool {
        if case .completed = self {
            return true
        }
        return false
    }
}

public struct ProgressIndicatorView: View {

    private let state: ProgressIndicatorState
    
    private let fullSize: CGFloat = 35

    // timed progress
    private let timer: Publishers.Autoconnect<Timer.TimerPublisher>
    @State private var progress: Double = 0
    private let startTime: CFTimeInterval
    private var finishTime: CFTimeInterval
    
    private var duration: TimeInterval {
        return max(0, finishTime - startTime)
    }
    
    public init(state: ProgressIndicatorState) {
        startTime = CACurrentMediaTime()
        self.state = state
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

        if case .timedProgress(let finishTime) = state {
            self.finishTime = finishTime
        } else {
            timer.upstream.connect().cancel()
            self.finishTime = startTime
        }
    }
    
    
        
    public var body: some View {
        ZStack {
            ActivityIndicator(isAnimating: .constant(true), style: .large)
                .opacity(self.state.showIndeterminantProgress ? 1 : 0)
                .frame(height: self.state.showIndeterminantProgress ? fullSize : 0)

            ZStack {
                ProgressView(progress: self.state.showProgressBar ? 1 : 0)
                    .frame(height: fullSize)
                    .animation(.linear(duration: self.duration))
            }
            .opacity(self.state.showProgressBar ? 1 : 0)
            .frame(height: self.state.showProgressBar ? fullSize : 0)

            Image(frameworkImage: "Checkmark").foregroundColor(Color.accentColor)
                .opacity(self.state.showCompletion ? 1 : 0)
                .scaleEffect(self.state.showCompletion ? 1.0 : 0.001)
                .animation(.spring(dampingFraction: 0.5))
                .frame(height: self.state.showCompletion ? fullSize : 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibility(label: Text(self.accessibilityLabel))
        .accessibility(hidden: self.state == .hidden)
        .onReceive(timer) { time in
            let elapsed = CACurrentMediaTime() - self.startTime
            self.progress = min(1.0, elapsed / self.duration)
            if self.progress >= 1.0 {
                self.timer.upstream.connect().cancel()
            }
        }
    }
    
    var accessibilityLabel: String {
        switch self.state {
        case .indeterminantProgress:
            return LocalizedString("Progressing.", comment: "Accessibility label for ProgressIndicatorView when showIndeterminantProgress")
        case .timedProgress:
            return String(format: LocalizedString("%1$d percent complete.", comment: "Format string for progress accessibility label (1: duration in seconds)"), Int((self.progress * 100).rounded()))
        case .completed:
            return LocalizedString("Completed.", comment: "Accessibility label for ProgressIndicatorView when showIndeterminantProgress")
        case .hidden:
            return ""
        }
    }
}

struct ProgressIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        ProgressPreviewWrapper()
    }
    
}

struct ProgressPreviewWrapper: View {
    @State var setupState: ProgressIndicatorState = .hidden
    @State private var modeIndex: Int = 0

    var body: some View {
        VStack {
            Rectangle().frame(height: 1)
            ProgressIndicatorView(state: setupState)
            Rectangle().frame(height: 1)

            Button(action: {
                let finishTime = TimeInterval(10)
                let modes: [ProgressIndicatorState] = [.indeterminantProgress, .timedProgress(finishTime: CACurrentMediaTime() + finishTime), .completed, .hidden]
                
                self.setupState = modes[self.modeIndex]
                self.modeIndex = (self.modeIndex + 1) % modes.count

            }) {
                Text("Switch Preview State")
            }
            Text(String(describing: self.setupState)).foregroundColor(Color.secondary).lineLimit(1)
        }
        .animation(.default)
        .padding()
    }
}
