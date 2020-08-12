//
//  OutsideDoseEvent.swift
//  LoopKit
//
//  Created by Anna Quinlan on 4/17/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//
import Foundation
import CoreData

class OutsideDoseEvent: PumpEvent {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<OutsideDoseEvent> {
        return NSFetchRequest<OutsideDoseEvent>(entityName: "OutsideDoseEvent");
    }
}
