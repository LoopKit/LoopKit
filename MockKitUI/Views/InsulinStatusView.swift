//
//  InsulinStatusView.swift
//  MockKitUI
//
//  Created by Nathaniel Hamming on 2023-05-18.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopAlgorithm
import LoopKit
import LoopKitUI

struct InsulinStatusView: View {
    @Environment(\.guidanceColors) var guidanceColors
    @Environment(\.insulinTintColor) var insulinTintColor

    @ObservedObject var viewModel: MockPumpManagerSettingsViewModel

    private let subViewSpacing: CGFloat = 16

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            deliveryStatus
                .fixedSize(horizontal: true, vertical: true)
            Spacer()
            Divider()
                .frame(height: dividerHeight)
                .offset(y:3)
            Spacer()
            reservoirStatus
                .fixedSize(horizontal: true, vertical: true)
        }
    }

    private var dividerHeight: CGFloat {
        guard inNoDelivery == false else {
            return 65 + subViewSpacing-10
        }

        return 65 + subViewSpacing
    }

    let basalRateFormatter = QuantityFormatter(for: .internationalUnitsPerHour)
    let reservoirVolumeFormatter = QuantityFormatter(for: .internationalUnit)

    private var inNoDelivery: Bool {
        !viewModel.isDeliverySuspended && viewModel.basalDeliveryRate == nil
    }

    private var deliveryStatusSpacing: CGFloat {
        return subViewSpacing - 8
    }

    var deliveryStatus: some View {
        VStack(alignment: .leading, spacing: deliveryStatusSpacing) {
            Text(deliverySectionTitle)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if viewModel.isDeliverySuspended {
                insulinSuspended
            } else if let basalRate = viewModel.basalDeliveryRate,
                      let date = viewModel.basalDeliveryRateDate
            {
                basalRateView(basalRate, at: date)
            } else {
                noDelivery
            }
        }
    }

    var insulinSuspended: some View {
        HStack(alignment: .center, spacing: 2) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 34))
                .fixedSize()
                .foregroundColor(guidanceColors.warning)
            Text("Insulin\nSuspended")
                .font(.system(size: 14, weight: .heavy, design: .default))
                .lineSpacing(0.01)
                .fixedSize()
        }
    }

    private func basalRateView(_ basalRate: Double, at date: Date) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading) {
                HStack(spacing: 3) {
                    if viewModel.presentDeliveryWarning == true {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(guidanceColors.warning)
                            .font(.system(size: 28))
                            .fixedSize()
                    }
                    Image(systemName: viewModel.automatedTreatmentState.imageName)
                        .font(.largeTitle)
                        .foregroundColor(.accentColor)
                    Text(viewModel.basalDisplayStateString)
                        .lineSpacing(1)
                        .font(.callout)
                        .fontWeight(.heavy)
                }
                if let basalDeliveryRateDateString = viewModel.basalDeliveryRateDateString {
                    Text("at \(basalDeliveryRateDateString)")
                        .font(.footnote)
                        .foregroundColor(.accentColor)
                }
            }
        }
    }

    var noDelivery: some View {
        HStack(alignment: .center, spacing: 2) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 34))
                .fixedSize()
                .foregroundColor(guidanceColors.critical)
            Text("No\nDelivery")
                .font(.system(size: 16, weight: .heavy, design: .default))
                .lineSpacing(0.01)
                .fixedSize()
        }
    }

    var deliverySectionTitle: String {
        LocalizedString("Insulin\(String.nonBreakingSpace)Delivery", comment: "Title of insulin delivery section")
    }

    private var reservoirStatusSpacing: CGFloat {
        subViewSpacing
    }

    var reservoirStatus: some View {
        VStack(alignment: .trailing) {
            VStack(alignment: .leading, spacing: reservoirStatusSpacing) {
                Text("Insulin\(String.nonBreakingSpace)Remaining")
                    .foregroundColor(Color(UIColor.secondaryLabel))
                HStack {
                    reservoirLevelStatus
                }
            }
        }
    }

    @ViewBuilder
    var reservoirLevelStatus: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                ZStack(alignment: .center) {
                    Image(frameworkImage: "generic-reservoir")
                        .resizable()
                        .foregroundColor(.accentColor)
                        .frame(width: 26, height: 34, alignment: .bottom)
                    Image(frameworkImage: "generic-reservoir-mask")
                        .resizable()
                        .foregroundColor(.accentColor)
                        .frame(width: 23, height: 34, alignment: .bottom)
                }
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("50+")
                        .font(.system(size: 28))
                        .fontWeight(.heavy)
                        .fixedSize()
                    Text(reservoirVolumeFormatter.localizedUnitStringWithPlurality())
                        .foregroundColor(.secondary)
                }
            }
            Text("Estimated Reading")
                .font(.footnote)
                .foregroundColor(.accentColor)
        }
        .offset(y: -7) // the reservoir image should have tight spacing so move the view up
        .padding(.bottom, -7)
    }
}
