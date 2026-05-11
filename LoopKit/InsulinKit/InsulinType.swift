//
//  InsulinType.swift
//  LoopKit
//
//  Created by Anna Quinlan on 12/8/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopAlgorithm

public enum InsulinType: Int, Codable, CaseIterable {
    case novolog
    case humalog
    case apidra
    case fiasp
    case lyumjev
    case afrezza
}

extension InsulinType {
    public var title: String {
        switch self {
        case .novolog:
            return LocalizedString("Novolog", comment: "Title for Novolog insulin type")
        case .humalog:
            return LocalizedString("Humalog (insulin lispro)", comment: "Title for Humalog insulin type")
        case .apidra:
            return LocalizedString("Apidra (insulin glulisine)", comment: "Title for Apidra insulin type")
        case .fiasp:
            return LocalizedString("Fiasp", comment: "Title for Fiasp insulin type")
        case .lyumjev:
            return LocalizedString("Lyumjev", comment: "Title for Lyumjev insulin type")
        case .afrezza:
            return LocalizedString("Afrezza", comment: "Title for Afrezza insulin type")
        }
    }
    
    public var brandName: String {
        switch self {
        case .novolog:
            return LocalizedString("Novolog", comment: "Brand name for novolog insulin type")
        case .humalog:
            return LocalizedString("Humalog", comment: "Brand name for humalog insulin type")
        case .apidra:
            return LocalizedString("Apidra", comment: "Brand name for apidra insulin type")
        case .fiasp:
            return LocalizedString("Fiasp", comment: "Brand name for fiasp insulin type")
        case .lyumjev:
            return LocalizedString("Lyumjev", comment: "Brand name for lyumjev insulin type")
        case .afrezza:
            return LocalizedString("Afrezza", comment: "Brand name for afrezza insulin type")
        }
    }
    
    public var description: String {
        switch self {
        case .novolog, .humalog:
            return LocalizedString("A rapid-acting insulin", comment: "Description for rapid acting insulin types")
        case .apidra:
            return LocalizedString("Apidra (insulin glulisine) is a rapid-acting insulin made by Sanofi-aventis ", comment: "Description for apidra insulin type")
        case .fiasp, .lyumjev:
            return LocalizedString("An ultra-rapid-acting insulin", comment: "Description for ultra rapid acting insulin types")
        case .afrezza:
            return LocalizedString("An ultra-rapid-acting mealtime insulin that is inhaled", comment: "Description for afrezza insulin type")
        }
    }

    public var pumpAdministerable: Bool {
        switch self {
        case .afrezza:
            return false
        default:
            return true
        }
    }
}
