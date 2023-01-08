//
//  VideoPlayView.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 5/12/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct VideoPlayView<ThumbnailContent: View>: View {
    let thumbnail: () -> ThumbnailContent
    let includeThumbnailBorder: Bool
    let centerThumbnail: Bool
    let url: URL?
    let hasBeenPlayed: Binding<Bool>
    private var _autoPlay: Bool = true
    private var _overrideMuteSwitch: Bool = true
    @State private var isActive: Bool = false
    
    // This from right out of the Design spec
    private let frameColor = Color(UIColor(red: 0.784, green: 0.784, blue: 0.784, alpha: 1))
    
    public init(url: URL?, thumbnail: @autoclosure @escaping () -> ThumbnailContent, includeThumbnailBorder: Bool = true, centerThumbnail: Bool = true) {
        self.url = url
        self.thumbnail = thumbnail
        self.includeThumbnailBorder = includeThumbnailBorder
        self.centerThumbnail = centerThumbnail
        self.hasBeenPlayed = .false
    }

    public init(url: URL?, thumbnail: @autoclosure @escaping () -> ThumbnailContent, hasBeenPlayed: Binding<Bool>, includeThumbnailBorder: Bool = true, centerThumbnail: Bool = true) {
        self.url = url
        self.thumbnail = thumbnail
        self.includeThumbnailBorder = includeThumbnailBorder
        self.centerThumbnail = centerThumbnail
        self.hasBeenPlayed = hasBeenPlayed
    }
    
    private init(_ other: Self, url: URL?? = nil, thumbnail: (() -> ThumbnailContent)? = nil, hasBeenPlayed: Binding<Bool>? = nil, autoPlay: Bool? = nil, overrideMuteSwitch: Bool? = nil, includeThumbnailBorder: Bool? = nil, centerThumbnail: Bool? = nil) {
        self.url = url ?? other.url
        self.thumbnail = thumbnail ?? other.thumbnail
        self.hasBeenPlayed = hasBeenPlayed ?? other.hasBeenPlayed
        self.includeThumbnailBorder = includeThumbnailBorder ?? other.includeThumbnailBorder
        self.centerThumbnail = centerThumbnail ?? other.centerThumbnail
        self._autoPlay = autoPlay ?? other._autoPlay
        self._overrideMuteSwitch = overrideMuteSwitch ?? other._overrideMuteSwitch
    }

    public var body: some View {
        PopoverLink(destination: videoView, isActive: $isActive) {
            if includeThumbnailBorder {
                placeholderImage
                    .padding()
                    .border(frameColor, width: 1)
            } else {
                placeholderImage
            }
        }
        .fullScreen()
    }

    private var placeholderImage: some View {
        HStack {
            if centerThumbnail {
                Spacer()
            }
            ZStack {
                thumbnail()
                Image(frameworkImage: "play-button", decorative: true)
            }
            if centerThumbnail {
                Spacer()
            }
        }
        .aspectRatio(CGSize(width: 16, height: 9), contentMode: .fit)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var videoView: some View {
        VideoView(url: url, autoPlay: _autoPlay, overrideMuteSwitch: _overrideMuteSwitch, isActive: $isActive)
            .onDisappear { hasBeenPlayed.wrappedValue = true }
    }
    
    public func autoPlay(_ enabled: Bool) -> Self {
        Self.init(self, autoPlay: enabled)
    }

    public func overrideMuteSwitch(_ enabled: Bool) -> Self {
        Self.init(self, overrideMuteSwitch: enabled)
    }

    public func includeThumbnailBorder(_ value: Bool) -> Self {
        Self.init(self, includeThumbnailBorder: value)
    }

    public func centerThumbnail(_ value: Bool) -> Self {
        Self.init(self, centerThumbnail: value)
    }
}

fileprivate extension Binding where Value == Bool {
    static var `true` = Binding(get: { true }, set: { _ in })
    static var `false` = Binding(get: { false }, set: { _ in })
}
