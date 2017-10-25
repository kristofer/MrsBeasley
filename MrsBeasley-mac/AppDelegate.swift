//
//  AppDelegate.swift
//  MrsBeasley-mac
//
//  Created by Kristofer on 10/24/17.
//  Copyright © 2017 Kristofer. All rights reserved.
//

import Cocoa
import CloudKit

let MrsBeasleyContainer = "iCloud.com.tiogadigital.MrsBeasley"

extension ViewController {
    
    var container: CKContainer {
        return CKContainer(identifier: MrsBeasleyContainer)
    }
    
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {



    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        CKContainer.default().accountStatus { status, error in
            if let error = error {
                // some error occurred (probably a failed connection, try again)
                print("need iCloud1", error)
                // launch an alert.
                
            } else {
                switch status {
                case .available:
                    // the user is logged in
                    self.configureCloudKit()
                case .noAccount:
                    // the user is NOT logged in
                    print("need iCloud2")
                case .couldNotDetermine:
                    // for some reason, the status could not be determined (try again)
                    print("couldNotDetermine need iCloud...")
                case .restricted:
                    // iCloud settings are restricted by parental controls or a configuration profile
                    print("restrictedneed iCloud...")
                }
            }
        }
        
    }

    private func configureCloudKit() {
        let container = CKContainer(identifier: MrsBeasleyContainer)
        
        container.privateCloudDatabase.fetchAllRecordZones { zones, error in
            guard let zones = zones, error == nil else {
                // error handling magic
                return
            }
            
            //print("I have these zones: \(zones)")
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

