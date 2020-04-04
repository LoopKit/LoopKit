//
//  PumpEvent.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 3/28/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import CoreData

enum InsulinModelType: Int {
    case walsh = 0
    case exponential
    case none
}

class PumpEvent: NSManagedObject {

    var doseType: DoseType? {
        get {
            willAccessValue(forKey: "doseType")
            defer { didAccessValue(forKey: "doseType") }
            return DoseType(rawValue: primitiveDoseType ?? "")
        }
        set {
            willChangeValue(forKey: "doseType")
            defer { didChangeValue(forKey: "doseType") }
            primitiveDoseType = newValue?.rawValue
        }
    }

    var duration: TimeInterval! {
        get {
            willAccessValue(forKey: "duration")
            defer { didAccessValue(forKey: "duration") }
            return primitiveDuration?.doubleValue
        }
        set {
            willChangeValue(forKey: "duration")
            defer { didChangeValue(forKey: "duration") }
            primitiveDuration = newValue != nil ? NSNumber(value: newValue) : nil
        }
    }

    var unit: DoseUnit? {
        get {
            willAccessValue(forKey: "unit")
            defer { didAccessValue(forKey: "unit") }
            return DoseUnit(rawValue: primitiveUnit ?? "")
        }
        set {
            willChangeValue(forKey: "unit")
            defer { didChangeValue(forKey: "unit") }
            primitiveUnit = newValue?.rawValue
        }
    }

    var modelPeak: Double? {
        get {
            willAccessValue(forKey: "modelPeak")
            defer { didAccessValue(forKey: "modelPeak") }
            return primitiveModelPeak?.doubleValue
        }
        set {
            willChangeValue(forKey: "modelPeak")
            defer { didChangeValue(forKey: "modelPeak") }
            primitiveModelPeak = newValue != nil ? NSNumber(value: newValue!) : nil
        }
    }
    
    var modelDelay: Double? {
        get {
            willAccessValue(forKey: "modelDelay")
            defer { didAccessValue(forKey: "modelDelay") }
            return primitiveModelDelay?.doubleValue
        }
        set {
            willChangeValue(forKey: "modelDelay")
            defer { didChangeValue(forKey: "modelDelay") }
            primitiveModelDelay = newValue != nil ? NSNumber(value: newValue!) : nil
        }
    }
    
    var modelDuration: Double? {
        get {
            willAccessValue(forKey: "modelDuration")
            defer { didAccessValue(forKey: "modelDuration") }
            return primitiveModelDuration?.doubleValue
        }
        set {
            willChangeValue(forKey: "modelDuration")
            defer { didChangeValue(forKey: "modelDuration") }
            primitiveModelDuration = newValue != nil ? NSNumber(value: newValue!) : nil
        }
    }
    
    private var modelType: InsulinModelType? {
        get {
            willAccessValue(forKey: "modelType")
            defer { didAccessValue(forKey: "modelType") }
            guard let type = primitiveModelType else {
                return nil
            }
            return InsulinModelType(rawValue: type.intValue)
        }
        set {
            willChangeValue(forKey: "modelType")
            defer { didChangeValue(forKey: "modelType") }
            primitiveModelType = newValue != nil ? NSNumber(value: newValue!.rawValue) : nil
        }
    }
    
    var type: PumpEventType? {
        get {
            willAccessValue(forKey: "type")
            defer { didAccessValue(forKey: "type") }
            return PumpEventType(rawValue: primitiveType ?? "")
        }
        set {
            willChangeValue(forKey: "type")
            defer { didChangeValue(forKey: "type") }
            primitiveType = newValue?.rawValue
        }
    }

    var uploaded: Bool {
        get {
            willAccessValue(forKey: "uploaded")
            defer { didAccessValue(forKey: "uploaded") }
            return primitiveUploaded?.boolValue ?? false
        }
        set {
            willChangeValue(forKey: "uploaded")
            defer { didChangeValue(forKey: "uploaded") }
            primitiveUploaded = NSNumber(value: newValue)
        }
    }

    var value: Double? {
        get {
            willAccessValue(forKey: "value")
            defer { didAccessValue(forKey: "value") }
            return primitiveValue?.doubleValue
        }
        set {
            willChangeValue(forKey: "value")
            defer { didChangeValue(forKey: "value") }
            primitiveValue = newValue != nil ? NSNumber(value: newValue!) : nil
        }
    }

    var deliveredUnits: Double? {
        get {
            willAccessValue(forKey: "deliveredUnits")
            defer { didAccessValue(forKey: "deliveredUnits") }
            return primitiveDeliveredUnits?.doubleValue
        }
        set {
            willChangeValue(forKey: "deliveredUnits")
            defer { didChangeValue(forKey: "deliveredUnits") }
            primitiveDeliveredUnits = newValue != nil ? NSNumber(value: newValue!) : nil
        }
    }

    override func awakeFromInsert() {
        super.awakeFromInsert()

        createdAt = Date()
    }
}


extension PumpEvent: TimelineValue {
    var startDate: Date {
        get {
            return date
        }
        set {
            date = newValue
        }
    }

    var endDate: Date {
        get {
            return date.addingTimeInterval(duration)
        }
        set {
            duration = newValue.timeIntervalSince(startDate)
        }
    }
}


extension PumpEvent {

    var dose: DoseEntry? {
        get {
            // To handle migration, we're requiring any dose to also have a PumpEventType
            guard let type = type, let value = value, let unit = unit else {
                return nil
            }
            
            var model: InsulinModel? = nil

            switch modelType {
            case .walsh:
                model = WalshInsulinModel(actionDuration: modelDuration!, delay: modelDelay ?? 600)
            case .exponential:
                model = ExponentialInsulinModel(actionDuration: modelDuration!, peakActivityTime: modelPeak!, delay: modelDelay ?? 600)
            default:
                break
            }

            return DoseEntry(
                type: doseType ?? DoseType(pumpEventType: type)!,
                startDate: startDate,
                endDate: endDate,
                value: value,
                unit: unit,
                deliveredUnits: deliveredUnits,
                syncIdentifier: syncIdentifier,
                insulinModel: model
            )
        }
        set {
            guard let entry = newValue else {
                return
            }
            
            doseType = entry.type
            startDate = entry.startDate
            endDate = entry.endDate
            value = entry.value
            unit = entry.unit
            deliveredUnits = entry.deliveredUnits
            modelDuration = entry.insulinModel?.effectDuration
            modelDelay = entry.insulinModel?.delay
            // ANNA TODO: could this be more elegant?
            if let model = entry.insulinModel as? ExponentialInsulinModel {
                modelPeak = model.peakActivityTime
                modelType = .exponential
            } else if let model = entry.insulinModel as? ExponentialInsulinModelPreset {
                modelPeak = (model.getExponentialModel() as! ExponentialInsulinModel).peakActivityTime
                modelType = .exponential
            } else if let _ = entry.insulinModel as? WalshInsulinModel {
                modelType = .walsh
            }
        }
    }

    var syncIdentifier: String? {
        return raw?.hexadecimalString
    }

    var isUploaded: Bool {
        return uploaded
    }

    var isMutable: Bool {
        return mutable
    }
}


