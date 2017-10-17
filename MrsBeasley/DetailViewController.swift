//
//  DetailViewController.swift
//  MrsBeasley
//
//  Created by Kristofer on 10/16/17.
//  Copyright © 2017 Kristofer. All rights reserved.
//

import UIKit
import CloudKit

class DetailViewController: UIViewController {
    
    var record = CKRecord(recordType: TDRecordTypeString)
    var recordItem: CKRecord? {
        didSet {
            // Update the view.
            configureView()
        }
    }
    
    @IBOutlet weak var detailDescriptionLabel: UILabel!
    // title location body
    @IBOutlet weak var bodyField: UITextView!
    @IBOutlet weak var titleField: UITextField!
    @IBOutlet weak var dateField: UITextField!
    @IBOutlet weak var locationField: UITextField!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    


    func configureView() {
        // Update the user interface for the detail item.
        if let record = recordItem {
            if let title = titleField {
                title.text = record[TDRecordKey.title] as! String?
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
            constant: -20).isActive = true
        // 3
        bodyField.heightAnchor.constraint(
            equalTo: view.heightAnchor,
            multiplier: 0.90).isActive = true
        
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
        configureView()
        setupConstraints()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Operations
    @IBAction func titleFieldAction(_ sender: Any) {
        guard let title = titleField.text else { return }
        
        record[.title] = title
    }
    
    @IBAction func bodyFieldAction(_ sender: Any) {
        guard let body = bodyField.text else { return }
        
        record[.body] = body
    }
    
    //    @IBAction func releaseDateFieldAction(_ sender: Any) {
    //        guard let dateString = dateField.text else { return }
    //
    //        let formatter = DateFormatter()
    //        formatter.dateFormat = "yyyy-MM-dd"
    //
    //        guard let date = formatter.date(from: dateString) else { return }
    //
    //        record[.releaseDate] = date
    //    }
    
    @IBAction func locationFieldAction(_ sender: Any) {
        guard let locationString = locationField.text else { return }
        
        CLGeocoder().geocodeAddressString(locationString) { placemarks, error in
            guard let placemark = placemarks?.first, error == nil else { return }
            
            self.record[.location] = placemark.location
            
            DispatchQueue.main.async {
                self.locationField.text = String(placemark)
            }
        }
    }
    
    @IBAction func save(_ sender: Any) {
        saveButton.isEnabled = false
        saveButton.isHidden = true
        activityIndicator.hidesWhenStopped = true
        activityIndicator.center = self.view.center
        self.activityIndicator.transform = CGAffineTransform(scaleX: 3, y: 3)
        activityIndicator.startAnimating()

        container.privateCloudDatabase.save(record) { [unowned self] _, error in
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                self.saveButton.isEnabled = true
                self.saveButton.isHidden = false
                
                if let error = error {
                    let alert = UIAlertController(title: "CloudKit error", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                } else {
                    //self.clear()
                    self.dismiss(animated: true, completion: nil)
                }
            }
        }
    }
    
    private func clear() {
        titleField.text = nil
        bodyField.text = nil
        //dateField.text = nil
        //locationField.text = nil
        
        record = CKRecord(recordType: TDRecordTypeString)
        
        _ = titleField.becomeFirstResponder()
    }

}

