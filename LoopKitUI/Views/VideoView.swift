//
//  VideoView.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 4/13/21.
//  Copyright © 2021 Tidepool Project. All rights reserved.
//

import SwiftUI
import AVKit

/// Opens a Swift `VideoPlayer` on the given URL in a new page
public struct VideoView: View {
    @Environment(\.dismissAction) var dismissAction

    let url: URL?
    let autoPlay: Bool
    public var isActive: Binding<Bool>?

    private class PlayerHolder {
        private let prevCategory: AVAudioSession.Category?
        private var player: AVPlayer?
        
        init(overrideMuteSwitch: Bool) {
            if overrideMuteSwitch {
                prevCategory = AVAudioSession.sharedInstance().category
            } else {
                prevCategory = nil
            }
        }
        
        func destroy() {
            if let prevCategory = prevCategory {
                try? AVAudioSession.sharedInstance().setCategory(prevCategory)
            }
        }
        
        func player(for url: URL, autoPlay: Bool) -> AVPlayer {
            if let player = player {
                return player
            } else {
                let player = AVPlayer(url: url)
                if autoPlay, player.timeControlStatus == .paused {
                    player.play()
                } else if !autoPlay, player.timeControlStatus == .playing {
                    player.pause()
                }
                if prevCategory != nil {
                    // Overrides mute switch (Silent mode) on the phone
                    try? AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback)
                }
                self.player = player
                return player
            }
        }
    }
    private let playerHolder: PlayerHolder

    public init(url: URL?, autoPlay: Bool, overrideMuteSwitch: Bool = false, isActive: Binding<Bool>? = nil) {
        self.url = url
        self.autoPlay = autoPlay
        self.playerHolder = PlayerHolder(overrideMuteSwitch: overrideMuteSwitch)
        self.isActive = isActive
    }

    private func dismiss() {
        guard isActive != nil else {
            dismissAction()
            return
        }

        isActive?.wrappedValue = false
    }
    
    public var body: some View {
        HStack {
            Spacer()
            Button(LocalizedString("Done", comment: "Video player done button label"), action: dismiss)
        }
        .padding()
        if let url = url {
            VideoPlayer(player: playerHolder.player(for: url, autoPlay: autoPlay))
                .onDisappear {
                    playerHolder.destroy()
                }
        } else {
            Spacer()
            Image(systemName: "questionmark.video")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100, alignment: .center)
            Spacer()
        }
    }
}

struct VideoView_Previews: PreviewProvider {
    static var previews: some View {
        VideoView(url: nil, autoPlay: true, overrideMuteSwitch: true)
    }
}
