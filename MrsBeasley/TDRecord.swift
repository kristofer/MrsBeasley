//
//  TDRecord.swift
//  MrsBeasley
//
//  Created by Kristofer on 10/16/17.
//  Copyright © 2017 Kristofer. All rights reserved.
//

import Foundation
import CloudKit
import CoreLocation

let TDRecordTypeString = "TDRecord"

// hmm

enum TDRecordKey: String {
    case title
    case location
    case body
}

extension CKRecord {
    
    subscript(key: TDRecordKey) -> Any? {
        get {
            return self[key.rawValue]
        }
        set {
            self[key.rawValue] = newValue as? CKRecordValue
        }
    }
    
}

extension String {
    
    init?(_ placemark: CLPlacemark) {
        guard let country = placemark.country, let locality = placemark.locality else { return nil }
        
        self = "\(locality), \(country)"
    }
    
}
