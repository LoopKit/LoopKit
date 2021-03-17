//
//  AlertSoundPlayer.swift
//  Loop
//
//  Created by Rick Pasetto on 4/27/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

#if os(watchOS)
import WatchKit
#else
import AudioToolbox
#endif
import AVFoundation
import os.log

public protocol AlertSoundPlayer {
    func vibrate()
    func play(url: URL)
    func stopAll()
}

public class DeviceAVSoundPlayer: AlertSoundPlayer {
    private let log = OSLog(category: "DeviceAVSoundPlayer")
    private let baseURL: URL?
    private var delegate: Delegate!
    private var players = [AVAudioPlayer]()
    
    @objc class Delegate: NSObject, AVAudioPlayerDelegate {
        weak var parent: DeviceAVSoundPlayer?
        init(parent: DeviceAVSoundPlayer) { self.parent = parent }
        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            parent?.players.removeAll { $0 == player }
        }
    }
    
    public init(baseURL: URL? = nil) {
        self.baseURL = baseURL
        self.delegate = Delegate(parent: self)
    }
    
    enum Error: Swift.Error {
        case playFailed
    }
    
    public func vibrate() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.notification)
        #else
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        #endif
    }
    
    public func play(url: URL) {
        DispatchQueue.main.async {
            do {
                let soundEffect = try AVAudioPlayer(contentsOf: url)
                soundEffect.delegate = self.delegate
                // The AVAudioPlayer has to remain around until the sound completes playing, which is why we hold
                // onto it until it completes.
                self.players.append(soundEffect)
                if !soundEffect.play() {
                    self.log.default("couldn't play sound (app may be in the background): %@", url.absoluteString)
                }
            } catch {
                self.log.error("couldn't play sound %@: %@", url.absoluteString, String(describing: error))
            }
        }
    }
    
    public func stopAll() {
        DispatchQueue.main.async {
            for soundEffect in self.players {
                soundEffect.stop()
            }
        }
    }
}

public extension DeviceAVSoundPlayer {

    func playAlert(sound: Alert.Sound) {
        switch sound {
        case .silence:
            // noop
            break
        case .vibrate:
            vibrate()
        default:
            if let baseURL = baseURL {
                if let name = sound.filename {
                    self.stopAll()
                    self.play(url: baseURL.appendingPathComponent(name))
                } else {
                    log.default("No file to play for %@", "\(sound)")
                }
            } else {
                log.error("No base URL, could not play %@", sound.filename ?? "")
            }
        }
    }
}
