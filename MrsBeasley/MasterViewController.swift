//
//  MasterViewController.swift
//  MrsBeasley
//
//  Created by Kristofer on 10/16/17.
//  Copyright © 2017 Kristofer. All rights reserved.
//

import UIKit
import CloudKit
import CoreLocation

public protocol SectionModelType {
    associatedtype Item
    
    var items: [Item] { get }
    
    init(original: Self, items: [Item])
}

struct SectionOfCKRecord {
    var header: String
    var items: [Item]
}
extension SectionOfCKRecord: SectionModelType {
    typealias Item = CKRecord
    
    init(original: SectionOfCKRecord, items: [Item]) {
        self = original
        self.items = items
    }
}

class MasterViewController: UITableViewController {

    var detailViewController: DetailViewController? = nil
    var objects = [CKRecord]()
    var sectionSource = [SectionOfCKRecord]()

    //var record = CKRecord(recordType: TDRecordTypeString)
    let dateFormater = DateFormatter()
    let backupCreationFormat = "(H:mm)"

    let sectionFormater = DateFormatter()
    let sectionHeaderFormat = "EEEE, dd MMMM yyyy"

    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!



    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        //navigationItem.leftBarButtonItem = editButtonItem

        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(insertNewObject(_:)))
        navigationItem.rightBarButtonItem = addButton
        if let split = splitViewController {
            let controllers = split.viewControllers
            detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
        }
        self.dateFormater.dateFormat = backupCreationFormat
        if #available(iOS 10.0, *) {
            let refreshControl = UIRefreshControl()
            let title = NSLocalizedString("PullToRefresh", comment: "Pull to refresh")
            refreshControl.attributedTitle = NSAttributedString(string: title)
            refreshControl.addTarget(self,
                                     action: #selector(refreshOptions(sender:)),
                                     for: .valueChanged)
            self.refreshControl = refreshControl
        }
    }
    @objc private func refreshOptions(sender: UIRefreshControl) {
        self.reloadFromiCloud()
        sender.endRefreshing()
    }
    override func viewWillAppear(_ animated: Bool) {
        clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
        self.reloadFromiCloud()

        super.viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc
    func insertNewObject(_ sender: Any) {
        let newOne = CKRecord(recordType: TDRecordTypeString)
        newOne[TDRecordKey.title] = "Untitled"

        newOne[TDRecordKey.body] = ""
        objects.insert(newOne, at: 0)
        container.privateCloudDatabase.save(newOne) { [unowned self] _, error in
            DispatchQueue.main.async {
                self.performDateGrouping()
                self.tableView.reloadData()
            }
        }
    }

    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            if let indexPath = tableView.indexPathForSelectedRow {
                let object = objects[indexPath.row]
                let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
                controller.recordItem = object
                controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
                controller.navigationItem.leftItemsSupplementBackButton = true
            }
        }
    }

    // MARK: - Table View

//    override func numberOfSections(in tableView: UITableView) -> Int {
//        return 1
//    }
    override func numberOfSections(in tableView: UITableView) -> Int  {
        return sectionSource.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        //return objects.count
        return sectionSource[section].items.count
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionSource[section].header
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        //let object = objects[indexPath.row]
        let object = sectionSource[indexPath.section].items[indexPath.row]

        cell.textLabel!.text = object[TDRecordKey.title] as! String?
        if let creat = object.creationDate {
            cell.detailTextLabel!.text = "* \(self.dateFormater.string(from: creat)) | \(self.dateFormater.string(from: object.modificationDate!))"
        } else {
            cell.detailTextLabel!.text = "pending..."
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let objDelete = objects[indexPath.row]
            container.privateCloudDatabase.delete(withRecordID: objDelete.recordID, completionHandler: { (recordID, error) in
                print("deleted: \(String(describing: recordID?.recordName))")            })
            objects.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
        }
    }

    func reloadFromiCloud() {
        self.objects.removeAll()
        activityIndicator.hidesWhenStopped = true
        activityIndicator.center = self.view.center
        self.activityIndicator.transform = CGAffineTransform(scaleX: 3, y: 3)
        activityIndicator.startAnimating()
        
        func doneOneRecord(_ record: CKRecord?) {
            if record != nil {
                self.objects.append(record!)
            }
        }
        
        func doneHere(_ record: CKRecord?, error: Error?) {
            if error != nil {
                print("restoreRealm: There was an error: \(String(describing: error))")
                return
            }
        }
        
        let predicate = NSPredicate(value: true)
        let query = CKQuery.init(recordType: TDRecordTypeString, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
        let queryOperation = CKQueryOperation (query: query)
        
        queryOperation.recordFetchedBlock = doneOneRecord
        
        queryOperation.queryCompletionBlock = {
            queryCursor, error in
            if error != nil {
                print("queryCompletionBlock error: \(String(describing: error!))")
            }
        }
        
        queryOperation.completionBlock = {
            print("query Done. completionBlock: backups found:\(self.objects.count)")
            
            DispatchQueue.main.async {
                self.performDateGrouping()
                self.tableView.reloadData()
                self.activityIndicator.stopAnimating()
            }
        }
        container
            .privateCloudDatabase.add(queryOperation)
        

    }

    func performDateGrouping() {
        sectionFormater.dateFormat = self.sectionHeaderFormat
        
        var lastDate = (objects[0].creationDate)! as Date
        var lastGroup = SectionOfCKRecord(header: sectionFormater.string(from: lastDate as Date), items: [])
        var dateGroups = [SectionOfCKRecord]()
        let calendar = NSCalendar.current
        
        self.sectionSource.removeAll()
        for element in objects {
            let currentDate = element.creationDate!
            let unitFlags : Set<Calendar.Component> = [.era, .day, .month, .year, .timeZone]
            let difference = calendar.dateComponents(unitFlags, from: lastDate, to: currentDate)
            //let cDate = sectionFormater.string(from: currentDate as Date)
            //print("Item Date: \(cDate), and diff: \(difference)")
            
            if difference.year! != 0 || difference.month! != 0 || difference.day! != 0 {
                lastDate = currentDate
                dateGroups.append(lastGroup)
                lastGroup = SectionOfCKRecord(header: sectionFormater.string(from: lastDate as Date), items: [element])
            } else {
                lastGroup.items.append(element)
            }
        }
        dateGroups.append(lastGroup)
        self.sectionSource = dateGroups
    }

}

