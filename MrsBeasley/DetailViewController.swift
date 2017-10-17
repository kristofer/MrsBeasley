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
            // Update the view.
            //configureView()
        }
    }
    let dateFormater = DateFormatter()
    let backupCreationFormat = "EEEE, dd MMMM yyyy (H:mm)"
    var bodyChanged = false
    
    // title location body
    @IBOutlet weak var bodyField: UITextView!
    @IBOutlet weak var titleField: UITextField!
    //@IBOutlet weak var changedField: UITextField!
    //@IBOutlet weak var dateField: UITextField!
    //@IBOutlet weak var locationField: UITextField!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    


    func configureView() {
        self.bodyChanged = false
        // Update the user interface for the detail item.
        if let record = recordItem {
            if let title = titleField {
                //print("title field...\(self.dateFormater.string(from: record.creationDate!))")
                title.text = self.dateFormater.string(from: record.creationDate!) //record[TDRecordKey.title] as! String?
            }
            if let body = bodyField {
                body.text = record[TDRecordKey.body] as! String?
            }
        }
    }

    func setupConstraints() {
        // 1
        bodyField.translatesAutoresizingMaskIntoConstraints = false
        // 2
        bodyField.leadingAnchor.constraint(
            equalTo: view.leadingAnchor).isActive = true
        bodyField.trailingAnchor.constraint(
            equalTo: view.trailingAnchor).isActive = true
        bodyField.bottomAnchor.constraint(
            equalTo: view.bottomAnchor,
            constant: -9).isActive = true
        // 3
        bodyField.heightAnchor.constraint(
            equalTo: view.heightAnchor,
            multiplier: 0.85).isActive = true
        
        // title
        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.centerXAnchor.constraint(
            equalTo: view.centerXAnchor).isActive = true
        titleField.bottomAnchor.constraint(
            equalTo: bodyField.topAnchor).isActive = true
        //
        titleField.setContentHuggingPriority(
            UILayoutPriority.required,
            for: .vertical)
        titleField.setContentCompressionResistancePriority(
            UILayoutPriority.required,
            for: .vertical)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.titleField.delegate = self
        self.bodyField.delegate = self
        activityIndicator.hidesWhenStopped = true
        activityIndicator.center = self.view.center
        activityIndicator.transform = CGAffineTransform(scaleX: 3, y: 3)
        self.dateFormater.dateFormat = backupCreationFormat
        self.saveButton.isEnabled = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        configureView()
        setupConstraints()
        _ = bodyField.becomeFirstResponder()
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
        print("didEndEditing")
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
        print("Saving...")
        self.view.endEditing(true)
        saveButton.isEnabled = false
        saveButton.isHidden = true
        activityIndicator.startAnimating()

        container.privateCloudDatabase.fetch(withRecordID: recordItem!.recordID, completionHandler: { (record, error) in
            if error != nil {
                print("Error fetching record: \(error!.localizedDescription)")
            } else {
                if let record = record, let recordItem = self.recordItem {
                    record.setObject(recordItem[TDRecordKey.title] as? CKRecordValue, forKey: TDRecordKey.title.rawValue)
                    record.setObject(recordItem[TDRecordKey.body] as? CKRecordValue, forKey: TDRecordKey.body.rawValue)
                }
                self.container.privateCloudDatabase.save(record!, completionHandler: { (savedRecord, saveError) in
                    self.activityIndicator.stopAnimating()
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

