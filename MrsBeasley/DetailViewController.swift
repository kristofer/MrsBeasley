//
//  DetailViewController.swift
//  MrsBeasley
//
//  Created by Kristofer on 10/16/17.
//  Copyright © 2017 Kristofer. All rights reserved.
//

import UIKit
import CloudKit

class DetailViewController: UIViewController, UITextViewDelegate, UITextFieldDelegate {
    
    var recordItem: CKRecord? { // active record in this detail.
        didSet {
        }
    }
    let dateFormater = DateFormatter()
    let backupCreationFormat = "EEEE, dd MMMM yyyy (H:mm)"
    var bodyChanged = false
    
    // title location body
    @IBOutlet weak var bodyField: UITextView!
    @IBOutlet weak var titleField: UITextField!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    


    func configureView() {
        self.bodyChanged = false
        // Update the user interface for the detail item.
        if let record = recordItem {
            if let title = titleField {
                title.text = self.dateFormater.string(from: record.creationDate!)
            }
            if let body = self.bodyField {
                body.text = record[TDRecordKey.body] as! String?
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.titleField.delegate = self
        self.bodyField.delegate = self
        self.activityIndicator.hidesWhenStopped = true
        self.activityIndicator.center = self.view.center
        self.activityIndicator.transform = CGAffineTransform(scaleX: 3, y: 3)
        self.dateFormater.dateFormat = backupCreationFormat
        self.saveButton.isEnabled = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.configureView()
        if reachability.connection != .none {
            self.bodyField.isEditable = true
            //_ = bodyField.becomeFirstResponder()
        } else {
            self.bodyField.isEditable = false
        }
    }
    override func viewWillDisappear(_ animated: Bool) {
        if self.bodyChanged {
            self.save(self)
            //self.bodyChanged = false
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    func textViewDidChange(_ textView: UITextView) {
        //print("textViewDidChange")
        self.bodyChanged = true
        self.saveButton.isEnabled = true
    }
    func textViewDidEndEditing(_ textView: UITextView) {
        //print("didEndEditing")
        //self.titleFieldAction(self)
        if self.bodyChanged {
            self.bodyFieldAction(self)
        }
    }

    // MARK: - Operations
    
    @IBAction func bodyFieldAction(_ sender: Any) {
        guard let body = bodyField.text else { return }
        recordItem![.title] = getFirstLine(body)
        recordItem![.body] = body
    }
    
    func getFirstLine(_ text: String) -> String {
        let till: Character = "\n"
        if let idx = text.characters.index(of: till) {
            return String(text[text.startIndex..<idx])
        }
        return text
    }
    
    @IBAction func save(_ sender: Any) {
        self.view.endEditing(true)
        self.saveButton.isEnabled = false
        //activityIndicator.startAnimating()

        container.privateCloudDatabase.fetch(withRecordID: recordItem!.recordID, completionHandler: { (record, error) in
            if error != nil {
                print("Error fetching record: \(error!.localizedDescription)")
            } else {
                if let record = record, let recordItem = self.recordItem {
                    record.setObject(recordItem[TDRecordKey.title] as? CKRecordValue, forKey: TDRecordKey.title.rawValue)
                    record.setObject(recordItem[TDRecordKey.body] as? CKRecordValue, forKey: TDRecordKey.body.rawValue)
                }
                self.container.privateCloudDatabase.save(record!, completionHandler: { (savedRecord, saveError) in
                    //self.activityIndicator.stopAnimating()
                    if saveError != nil {
                        print("Error saving record: \(String(describing: saveError?.localizedDescription))")
                        if let error = saveError {
                            let alert = UIAlertController(title: "CloudKit error", message: error.localizedDescription, preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                            self.present(alert, animated: true, completion: nil)
                        }
                    } else {
                        //print("Successfully updated record!")
                    }
                })
            }
        })
    }
    
}

