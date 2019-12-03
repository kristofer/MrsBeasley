//
//  ProjectTags.swift
//  MrsBeasley
//
//  Created by Kristofer on 11/12/17.
//  Copyright © 2017 Kristofer. All rights reserved.
//

import Foundation
import UIKit
import CloudKit

class ProjectTags: UITableViewController {
    var iCloudKeyStore: NSUbiquitousKeyValueStore? = NSUbiquitousKeyValueStore()
    let tagsKey = "com.tioadigital.MrsBeasleyTags"
    var tagsArray: [String] = []
    var textViewToInsertInto: UITextView?
    var actualRecord: CKRecord?
    
    func saveToiCloud() {
        iCloudKeyStore?.set(tagsArray, forKey: self.tagsKey)
        iCloudKeyStore?.synchronize()
    }
    
    func iCloudSetUp() {
        if let newArray = iCloudKeyStore?.array(forKey: self.tagsKey) {
            self.tagsArray = newArray as! [String]
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(ProjectTags.ubiquitousKeyValueStoreDidChange),
                                               name:  NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                               object: iCloudKeyStore)
        
    }
    
    @objc func ubiquitousKeyValueStoreDidChange(notification: NSNotification) {
        self.tagsArray = iCloudKeyStore?.array(forKey: self.tagsKey) as! [String]
    }
    
    func append(tag: String) {
        self.tagsArray.append(tag)
        self.saveToiCloud()
    }
    func values() -> [String] {
        return self.tagsArray
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.iCloudSetUp()
        self.navigationItem.rightBarButtonItem = self.editButtonItem
        self.navigationItem.title = "Project Tags"
        self.tableView.reloadData()
        self.tableView.allowsSelectionDuringEditing = true
        self.tableView.delegate = self
        
    }
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        self.tableView.reloadData()
        self.tableView.setEditing(editing, animated: animated)
    }
    override func numberOfSections(in tableView: UITableView) -> Int  {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let addRow = self.isEditing ? 1 : 0
        return self.tagsArray.count + addRow
    }
    //     func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    //        return "Project Tags"
    //    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) 
        
        if(indexPath.row >= self.tagsArray.count && self.isEditing){
            cell.textLabel!.text = "Add Row"
        }else{
            let object = self.tagsArray[indexPath.row]
            cell.textLabel!.text = object
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if self.isEditing {
            if indexPath.row >= self.tagsArray.count {
                self.addTag()
            }
        } else {
            let txt = self.tagsArray[indexPath.row]
            //print("text: \(self.textViewToInsertInto?.text) \(self.textViewToInsertInto?.selectedRange)")
            self.textViewToInsertInto!.insertText("\(txt): ")
            self.actualRecord![TDRecordKey.body] =  self.textViewToInsertInto?.text
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if reachability.connection != .unavailable {
            return true
        }
        return false
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        if(indexPath.row >= self.tagsArray.count){
            return .insert
        } else {
            //use the delete icon on this row
            return .delete
        }
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let objDelete = self.tagsArray[indexPath.row]
            let didx = self.tagsArray.firstIndex(of: objDelete)
            self.tagsArray.remove(at: didx!)
            self.saveToiCloud()
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            print("inserting")
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
        }
    }
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let movedObject = self.tagsArray[sourceIndexPath.row]
        self.tagsArray.remove(at: sourceIndexPath.row)
        self.tagsArray.insert(movedObject, at: destinationIndexPath.row)
        self.saveToiCloud()
        NSLog("%@", "\(sourceIndexPath.row) => \(destinationIndexPath.row) \(self.tagsArray)")
        // To check for correctness enable: self.tableView.reloadData()
    }
    
    func addTag() {
        let alertController = UIAlertController(title: "Add Project Tag", message: "give a short project name", preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: "Add", style: .default, handler: {
            alert -> Void in
            let textField0 = alertController.textFields![0] as UITextField
            // do something with textField
            let foo = textField0.text!
            self.tagsArray.append(foo)
            self.tableView.reloadData()
            self.saveToiCloud()
        }))
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        alertController.addTextField(configurationHandler: {(textField : UITextField!) -> Void in
            textField.placeholder = "Untitled"
        })
        
        let alertWindow = UIWindow(frame: UIScreen.main.bounds)
        alertWindow.rootViewController = UIViewController()
        alertWindow.windowLevel = UIWindow.Level.alert + 1;
        alertWindow.makeKeyAndVisible()
        alertWindow.rootViewController?.present(alertController, animated: true, completion: nil)
        
    }
    
}
