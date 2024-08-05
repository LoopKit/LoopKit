//
//  HeartbeatFobPairingView.swift
//  MockKit
//
//  Created by Pete Schwamb on 4/9/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import SwiftUI
import MockKit

struct HeartbeatFobPairingView: View {

    @ObservedObject var heartbeatFob: HeartbeatFob
    @Environment(\.guidanceColors) private var guidanceColors

    var body: some View {
        List {
            Image(frameworkImage: "Heartbeat Fob")
                .resizable()
                .scaledToFit()
                .frame(height: 150)
                .frame(maxWidth: .infinity,maxHeight: .infinity)
            Section(header: HStack {
                Text(LocalizedString("Scanning", comment: "Header for devices section of HeartbeatFobPairingView"))
                ProgressView()
                    .padding(.leading, 5)
            }) {
                ForEach(heartbeatFob.discoveredFobs) { device in
                    HStack {
                        Image(systemName: device.isSelected ? "largecircle.fill.circle" : "circle")
                            .renderingMode(.original)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18)
                            .padding(.trailing, 5)
                        VStack {
                            HStack {
                                Text(device.displayName)
                                Spacer()

                                if device.isSelected {
                                    switch device.peripheralState {
                                    case .connected:
                                        if #available(iOSApplicationExtension 17.0, *) {
                                            Image(systemName: "dot.radiowaves.left.and.right")
                                                .imageScale(.large)
                                                .symbolRenderingMode(.multicolor)
                                                .symbolEffect(.variableColor, options: .speed(1), isActive: true)
                                        } else {
                                            Image(systemName: "dot.radiowaves.left.and.right")
                                                .imageScale(.large)
                                                .symbolRenderingMode(.multicolor)
                                        }
                                    default:
                                        ProgressView()
                                    }
                                }
                            }
                            HStack {
                                if let imageName = device.batteryImageName, let percent = device.batteryPercent {
                                    Text("\(percent)% Battery")
                                        .foregroundStyle(.secondary)
                                    Image(systemName: imageName)
                                        .padding(.leading, 5)
                                } else {
                                    Text("Battery Level Unknown")
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        heartbeatFob.toggleFobSelection(device.id)
                    }
                }
            }
            .onAppear {
                heartbeatFob.resumeScanning()
                heartbeatFob.triggerBatteryLevelRead()
            }
            .onDisappear {
                heartbeatFob.stopScanning()
            }
        }
        .navigationTitle(LocalizedString("Heartbeat Pairing", comment: "Navigation title for Heartbeat Fob Pairing View"))

    }

}

#Preview {
    HeartbeatFobPairingView(heartbeatFob: HeartbeatFob(fobId: nil, peripheralIdentifier: nil))
}
