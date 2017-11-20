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

// data structures for the sectioned by date that I display.
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

class NoteShowCell: UITableViewCell {
    @IBOutlet weak var textView: UITextView!
}


class MasterViewController: UITableViewController {
    var detailViewController: DetailViewController? = nil
    var objects = [CKRecord]()
    var sectionSource = [SectionOfCKRecord]()
    
    //var record = CKRecord(recordType: TDRecordTypeString)
    let dateFormater = DateFormatter()
    let backupCreationFormat = "H:mm"
    
    let sectionFormater = DateFormatter()
    let sectionHeaderFormat = "EEEE, dd MMMM yyyy"
    
    //var currentOrderby = creationOrderby

    

    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        //navigationItem.leftBarButtonItem = editButtonItem
        
        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(insertNewObject(_:)))
        navigationItem.rightBarButtonItem = addButton
        let menuButton = UIBarButtonItem(barButtonSystemItem: .organize, target: self, action: #selector(popMenu(_:)))
        navigationItem.leftBarButtonItem = menuButton

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
        tableView.estimatedRowHeight = 70
        tableView.rowHeight = UITableViewAutomaticDimension

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
        if reachability.connection != .none {
            let newOne = CKRecord(recordType: TDRecordTypeString)
            newOne[TDRecordKey.title] = ""
            
            newOne[TDRecordKey.body] = ""
            objects.insert(newOne, at: 0)
            container.privateCloudDatabase.save(newOne) { [unowned self] _, error in
                DispatchQueue.main.async {
                    self.performDateGrouping()
                    self.tableView.reloadData()
                    self.tableView.selectRow(at: IndexPath(row:0, section: 0), animated: true, scrollPosition: .top)
                    self.performSegue(withIdentifier: "showDetail", sender: nil)
                }
            }
            return
        }
        self.networkOffline()
    }
    
    @objc
    func popMenu(_ sender: Any) {
        let actionSheetController: UIAlertController = UIAlertController(title: "Organize", message: "ordering by \(self.currentOrderby)", preferredStyle: .actionSheet)
        
        //Create and add the Cancel action
        let cancelAction: UIAlertAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel) { action -> Void in
            //Just dismiss the action sheet
        }
        actionSheetController.addAction(cancelAction)

        let toggleOrder: UIAlertAction = UIAlertAction(title: "Toggle 'Order By'", style: UIAlertActionStyle.default) { action -> Void in
            if self.currentOrderby == MasterViewController.creationOrderby {
                self.currentOrderby = MasterViewController.modificationOrderby
            } else {
                self.currentOrderby = MasterViewController.creationOrderby
            }
            self.reloadFromiCloud()
        }
        actionSheetController.addAction(toggleOrder)

        let tags: UIAlertAction = UIAlertAction(title: "Manage Tags", style: UIAlertActionStyle.default) { action -> Void in
            self.performSegue(withIdentifier: "ShowTags", sender: self)
        }
        actionSheetController.addAction(tags)

        actionSheetController.popoverPresentationController?.sourceView = view
        actionSheetController.popoverPresentationController?.sourceRect = self.view.frame
        
        //Present the AlertController
        DispatchQueue.main.async{
            self.present(actionSheetController, animated: true, completion: nil)
        }

    }
    
    // MARK: - Segues
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            if let indexPath = tableView.indexPathForSelectedRow {
                let object = sectionSource[indexPath.section].items[indexPath.row] //objects[indexPath.row]
                let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
                controller.recordItem = object
                controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
                controller.navigationItem.leftItemsSupplementBackButton = true
            }
        }
        // "Project Tags"
        if segue.identifier == "ShowTags" {
            let controller = segue.destination as! ProjectTags
            controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
            controller.navigationItem.leftItemsSupplementBackButton = true
        }
   }
    
    // MARK: - Table View
    
    override func numberOfSections(in tableView: UITableView) -> Int  {
        if sectionSource.count > 0 {
            self.tableView.backgroundView = nil
            self.tableView.separatorStyle = .singleLine
            return sectionSource.count
        }
        
        self.setupNothingFound()
        return 0
    }
    
    func setupNothingFound() {
        let rect = CGRect(x: 0,
                          y: 0,
                          width: self.tableView.bounds.size.width,
                          height: self.tableView.bounds.size.height)
        let noDataLabel: UILabel = UILabel(frame: rect)
        noDataLabel.text = "No items found. Are you logged into iCloud?"
        noDataLabel.textColor = UIColor.white
        noDataLabel.textAlignment = NSTextAlignment.center
        self.tableView.backgroundView = noDataLabel
        self.tableView.separatorStyle = .none
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sectionSource[section].items.count
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionSource[section].header
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell:NoteShowCell = tableView.dequeueReusableCell(withIdentifier: "NoteTextCell", for: indexPath) as! NoteShowCell

        let object = sectionSource[indexPath.section].items[indexPath.row]
        cell.textLabel!.text = (object[TDRecordKey.body] as! String?)! + "\n| \(self.dateFormater.string(from: object.modificationDate!))"

        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if reachability.connection != .none {
            return true
        }
        return false
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let objDelete = sectionSource[indexPath.section].items[indexPath.row]
            container.privateCloudDatabase.delete(withRecordID: objDelete.recordID, completionHandler: { (recordID, error) in
                print("deleted: \(String(describing: recordID?.recordName))")            })
            let didx = objects.index(of: objDelete)
            objects.remove(at: didx!)
            self.performDateGrouping()
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
        }
    }
    
    func reloadFromiCloud() {
        
        if reachability.connection != .none {
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
            query.sortDescriptors = [NSSortDescriptor(key: self.currentOrderby, ascending: false)]
            let queryOperation = CKQueryOperation (query: query)
            
            queryOperation.recordFetchedBlock = doneOneRecord
            
            queryOperation.queryCompletionBlock = {
                queryCursor, error in
                if error != nil {
                    DispatchQueue.main.async {
                        print("queryCompletionBlock error: \(String(describing: error!))")
                        let mesg = "Need to login into iCloud." + String(describing: error!)
                        let alert = UIAlertController(title: "iCloud Needed.", message: mesg, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                    }
                }
            }
            
            queryOperation.completionBlock = {
                //print("query Done. completionBlock: records found:\(self.objects.count)")
                DispatchQueue.main.async {
                    self.performDateGrouping()
                    self.tableView.reloadData()
                    self.activityIndicator.stopAnimating()
                }
            }
            container
                .privateCloudDatabase.add(queryOperation)
        }
        
    }
    
    func performDateGrouping() {
        sectionFormater.dateFormat = self.sectionHeaderFormat
        if objects.count > 0 {
            var lastDate = (self.currentOrderby == MasterViewController.creationOrderby) ? (objects[0].creationDate)!: (objects[0].modificationDate)!
                //(objects[0].creationDate)! as Date
            var lastGroup = SectionOfCKRecord(header: sectionFormater.string(from: lastDate as Date), items: [])
            var dateGroups = [SectionOfCKRecord]()
            let calendar = NSCalendar.current
            
            self.sectionSource.removeAll()
            for element in objects {
                let currentDate = (self.currentOrderby == MasterViewController.creationOrderby) ? element.creationDate!: element.modificationDate!
                let unitFlags : Set<Calendar.Component> = [.era, .day, .month, .year, .hour, .minute, .timeZone]
                let difference = calendar.dateComponents(unitFlags, from: lastDate, to: currentDate)
                // still don't have this quite precisely right.
//                let pdiff = calendar.dateComponents(unitFlags, from: currentDate, to: lastDate)
//                let cDate = sectionFormater.string(from: currentDate as Date)
//                let lDate = sectionFormater.string(from: lastDate as Date)
//                print("Date: \(cDate)/\(lDate), and \ndiff: \(difference) \npdiff \(pdiff)")
                
                if difference.year! != 0 || difference.month! != 0 || difference.day! != 0
                 || difference.hour! < -12 {
                    //print("switch date")
                    lastDate = currentDate
                    dateGroups.append(lastGroup)
                    lastGroup = SectionOfCKRecord(header: sectionFormater.string(from: lastDate as Date), items: [element])
                } else {
                    //print("same date")
                    lastGroup.items.append(element)
                }
            }
            dateGroups.append(lastGroup)
            self.sectionSource = dateGroups
        }
    }
    
    func networkOffline() {
        if reachability.connection == .none {
            let alert = UIAlertController(title: "iCloud Needed.", message: "network is offline. unable to perform this operation.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
}

