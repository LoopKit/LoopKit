//
//  InsulinScaleInformationView.swift
//  Loop
//
//  Created by Pete Schwamb on 2/25/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//


import SwiftUI

struct InsulinScaleInformationView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Close button
            VStack {
                Button("Close") {
                    dismiss()
                }
                .font(.title3)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding()
            }
            .background(Color(.systemBackground))

            // Header
            VStack(alignment: .leading) {
                Text("Overall Insulin")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.vertical)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .background(Color(.systemBackground))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Description Text
                    Text("Overall insulin should be adjusted when your body needs more or less insulin than usual.")
                        .padding(.top)

                    Text("At 100%, your settings remain unchanged from your scheduled settings.")

                    // What gets affected
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Changing the percentage will affect:")
                            .fontWeight(.medium)

                        BulletPoint(text: "Basal Rate")
                        BulletPoint(text: "Carb Ratio")
                        BulletPoint(text: "Insulin Sensitivity Factor (ISF)")
                    }

                    // Decision guidance
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Before deciding to adjust your overall insulin,")
                        Text("ask yourself, does my body need more or less than usual?")
                            .fontWeight(.bold)
                    }

                    // Tip section
                    TipSection()
                }
                .padding()
            }
        }
    }
}

struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top) {
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            Text(text)
                .padding(.leading, 4)
        }
    }
}

struct TipSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.blue)

                Text("Tip")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            .padding(.bottom, 4)

            HStack(alignment: .top) {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)

                VStack(alignment: .leading) {
                    Text("A percentage ") +
                    Text("below 100%").fontWeight(.semibold) +
                    Text(" tells the system you need less insulin")
                }
            }

            HStack(alignment: .top) {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)

                VStack(alignment: .leading) {
                    Text("A percentage ") +
                    Text("above 100%").fontWeight(.semibold) +
                    Text(" indicates you need more insulin")
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

struct OverallInsulinView_Previews: PreviewProvider {
    static var previews: some View {
        InsulinScaleInformationView()
    }
}
