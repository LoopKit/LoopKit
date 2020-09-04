//
//  HKObject.swift
//  LoopKit
//
//  Created by Darin Krauss on 8/11/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit

extension HKObject {
    public var syncIdentifier: String? { metadata?[HKMetadataKeySyncIdentifier] as? String }
    public var syncVersion: Int? { metadata?[HKMetadataKeySyncVersion] as? Int }
}
