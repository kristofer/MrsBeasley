//
//  UserViewController.swift
//  MrsBeasley
//
//  Created by Kristofer on 10/16/17.
//  Copyright © 2017 Kristofer. All rights reserved.
//

import Foundation
//
//  UserViewController.swift
//  CloudKitchenSink
//
//  Created by Guilherme Rambo on 05/03/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//
import UIKit
import CloudKit

class UserViewController: UIViewController {
    
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var noAccountView: UIStackView!
    
    @IBOutlet weak var avatarSpinner: UIActivityIndicatorView!
    @IBOutlet weak var avatarContainerView: UIView! {
        didSet {
            avatarContainerView.clipsToBounds = true
            avatarContainerView.layer.cornerRadius = avatarContainerView.bounds.height / 2
        }
    }
    
    @IBOutlet weak var avatarImageView: UIImageView!
    
    var userRecord: CKRecord? {
        didSet {
            if let userRecord = userRecord {
                if let avatar = userRecord["avatar"] as? CKAsset {
                    avatarImageView.image = UIImage(contentsOfFile: avatar.fileURL!.path)
                }
                
                avatarContainerView.isHidden = false
            } else {
                avatarContainerView.isHidden = true
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(startDiscoveryProcess), name: Notification.Name.CKAccountChanged, object: nil)
        
        startDiscoveryProcess()
    }
    
    @objc private func startDiscoveryProcess() {
        self.noAccountView.isHidden = true
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        container.accountStatus { status, error in
            DispatchQueue.main.async {
                if let error = error {
                    let alert = UIAlertController(title: "Account Error", message: "Unable to determine iCloud account status.\n\(error.localizedDescription)", preferredStyle: .alert)
                    self.present(alert, animated: true, completion: nil)
                    
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                } else {
                    switch status {
                    case .available:
                        self.fetchUserRecordIdentifier()
                    case .couldNotDetermine, .noAccount, .restricted:
                        UIApplication.shared.isNetworkActivityIndicatorVisible = false
                        self.showNoAccountInfo()
                    @unknown default:
                        print("bad default")
                    }
                }
            }
        }
    }
    
    private func showNoAccountInfo() {
        self.noAccountView.isHidden = false
    }
    
    @IBAction func logIn(_ sender: Any) {
        UIApplication.shared.open(URL(string: "App-Prefs:root=Settings")!, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: nil)
    }
    
    private func fetchUserRecordIdentifier() {
        container.fetchUserRecordID { recordID, error in
            guard let recordID = recordID, error == nil else {
                // error handling magic
                return
            }
            
            DispatchQueue.main.async {
                self.idLabel.text = recordID.recordName
                
                print("Got user record ID \(recordID.recordName). Fetching info...")
                
                self.fetchUserRecord(with: recordID)
                self.discoverIdentity(for: recordID)
                self.discoverFriends()
            }
        }
    }
    
    private func fetchUserRecord(with recordID: CKRecord.ID) {
        container.publicCloudDatabase.fetch(withRecordID: recordID) { record, error in
            guard let record = record, error == nil else {
                // show off your error handling skills
                return
            }
            
            print("The user record is: \(record)")
            
            DispatchQueue.main.async {
                self.userRecord = record
            }
        }
    }
    
    private func discoverIdentity(for recordID: CKRecord.ID) {
        container.requestApplicationPermission(.userDiscoverability) { status, error in
            guard status == .granted, error == nil else {
                // error handling voodoo
                DispatchQueue.main.async {
                    self.nameLabel.text = "NOT AUTHORIZED"
                }
                return
            }
            
            self.container.discoverUserIdentity(withUserRecordID: recordID) { identity, error in
                defer {
                    DispatchQueue.main.async {
                        UIApplication.shared.isNetworkActivityIndicatorVisible = false
                    }
                }
                
                guard let components = identity?.nameComponents, error == nil else {
                    // more error handling magic
                    return
                }
                
                DispatchQueue.main.async {
                    let formatter = PersonNameComponentsFormatter()
                    self.nameLabel.text = formatter.string(from: components)
                }
            }
        }
    }
    
    private func discoverFriends() {
        container.discoverAllIdentities { identities, error in
            guard let identities = identities, error == nil else {
                // awesome error handling
                return
            }
            
            print("User has \(identities.count) contact(s) using the app:")
            print("\(identities)")
        }
    }
    
    @IBAction func changeAvatar(_ sender: Any) {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .photoLibrary
        imagePicker.delegate = self
        present(imagePicker, animated: true, completion: nil)
    }
    
}


extension UserViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
// Local variable inserted by Swift 4.2 migrator.
let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)

        defer {
            picker.dismiss(animated: true, completion: nil)
        }
        
        guard let userRecord = userRecord,
            let image = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as? UIImage,
            let imageData = image.pngData()
            else {
                print("Missing some data, unable to set the avatar now")
                return
        }
        
        let previousImage = avatarImageView.image
        avatarImageView.image = image
        
        do {
            let path = NSTemporaryDirectory() + "avatar_temp_\(UUID().uuidString).png"
            let url = URL(fileURLWithPath: path)
            
            try imageData.write(to: url)
            
            updateUserRecord(userRecord, with: url, fallbackImage: previousImage)
        } catch {
            print("Error writing avatar to temporary directory: \(error)")
        }
    }
    
    private func updateUserRecord(_ userRecord: CKRecord, with avatarURL: URL, fallbackImage: UIImage?) {
        avatarSpinner.startAnimating()
        avatarImageView.alpha = 0.5
        
        userRecord["avatar"] = CKAsset(fileURL: avatarURL)
        
        container.privateCloudDatabase.save(userRecord) { _, error in
            defer {
                DispatchQueue.main.async {
                    self.avatarImageView.alpha = 1
                    self.avatarSpinner.stopAnimating()
                    
                    do {
                        try FileManager.default.removeItem(at: avatarURL)
                    } catch {
                        print("Error deleting temporary avatar file: \(error)")
                    }
                }
            }
            
            guard error == nil else {
                // top-notch error handling
                DispatchQueue.main.async {
                    self.avatarImageView.image = fallbackImage
                }
                return
            }
            
            print("Successfully updated user record with new avatar")
        }
    }
    
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
	return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
	return input.rawValue
}
