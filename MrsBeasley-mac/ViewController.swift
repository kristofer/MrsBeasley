//
//  ViewController.swift
//  MrsBeasley-mac
//
//  Created by Kristofer on 10/24/17.
//  Copyright © 2017 Kristofer. All rights reserved.
//

import Cocoa
import CloudKit

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

class NoteShowCell: NSTableCellView {
    @IBOutlet weak var textView: NSTextView!
}


class ViewController: NSViewController, NSTableViewDelegate, NSTextViewDelegate, NSTextDelegate {

    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var textView: NSTextView!
    var objects = [CKRecord]()
    var sectionSource = [SectionOfCKRecord]()
    var selectedRecord: CKRecord?
    var selectedRow: Int?
    var oldSelectedRow: Int?

    //var record = CKRecord(recordType: TDRecordTypeString)
    let dateFormater = DateFormatter()
    let backupCreationFormat = "H:mm"
    
    let sectionFormater = DateFormatter()
    let sectionHeaderFormat = "EEEE, dd MMMM yyyy"
    var tableViewCellForSizing: NSTableCellView?
    
//    var currentOrderby = creationOrderby
//    static let creationOrderby = "creationDate"
//    static let modificationOrderby = "modificationDate"

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableViewCellForSizing = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "CellView"), owner: self) as? NSTableCellView
        self.dateFormater.dateFormat = backupCreationFormat
        let font = NSFont(name: "Optima-Regular", size: 16)
        let attributes = NSDictionary(object: font!, forKey: NSAttributedStringKey.font as NSCopying)
        
        self.textView.textContainerInset = NSMakeSize(20, 20)
        self.textView.typingAttributes = attributes as! [NSAttributedStringKey : Any]
        self.textView.delegate = self
        //self.textView.resignFirstResponder()
        //self.textView.textStorage?.delegate = self
        //self.textView.
        
        self.tableView.delegate = self
        self.tableView.gridStyleMask = NSTableView.GridLineStyle.solidHorizontalGridLineMask

        self.doReload(nil)
    }
    func doReload(_ newRecord: CKRecord?) {
        if newRecord == nil {
            self.oldSelectedRow = self.selectedRow
        } else {
            self.oldSelectedRow = 1
        }
        self.clearSelection()
        self.reloadFromiCloud(newRecord)
    }
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    //MARK: - NSTextDelegate

    func textDidChange(_ notification: Notification) {
        //print("textDidChange \(notification.name)")
        if let _:NSTextView = notification.object as? NSTextView {
            self.view.window?.isDocumentEdited = true
        }
    }
//    func textDidBeginEditing(_ notification: Notification) {
//        print("textDidBeginEditing \(notification.name)")
//    }
    
    func textDidEndEditing(_ notification: Notification) {
        //print("textDidEndEditing \(notification.name)")
        if let _:NSTextView = notification.object as? NSTextView {
            self.view.window?.isDocumentEdited = true
        }
    }
    func getFirstLine(_ text: String) -> String {
        let till: Character = "\n"
        if let idx = text.characters.index(of: till) {
            return String(text[text.startIndex..<idx])
        }
        return text
    }

    func ifEditedSave() {
        if (self.view.window?.isDocumentEdited)! {
            if self.selectedRecord != nil && self.selectedRow != nil {
                let body = self.textView.string
                self.selectedRecord![.title] = getFirstLine(body)
                self.selectedRecord![.body] = body
                self.saveSelectedRecord()
                return
            }
        }
    }
    
    func clearSelection() {
        self.selectedRecord = nil
        self.selectedRow = nil
        self.oldSelectedRow = nil
        self.textView.string = ""
        self.textView.isEditable = false
    }
    @IBAction func saveDocument(_ sender: Any?) {
        //print("saveDocument \(String(describing: self.selectedRow))")
        //self.textView.textStorage?.endEditing()
        self.ifEditedSave()
    }
    
    func saveSelectedRecord() {

        container.privateCloudDatabase.fetch(withRecordID: selectedRecord!.recordID, completionHandler: { (record, error) in
            if error != nil {
                print("Error fetching record: \(error!.localizedDescription)")
            } else {
                if let record = record, let recordItem = self.selectedRecord {
                    record.setObject(recordItem[TDRecordKey.title] as? CKRecordValue, forKey: TDRecordKey.title.rawValue)
                    record.setObject(recordItem[TDRecordKey.body] as? CKRecordValue, forKey: TDRecordKey.body.rawValue)
                }
                self.container.privateCloudDatabase.save(record!, completionHandler: { (savedRecord, saveError) in
                    //self.activityIndicator.stopAnimating()
                    if saveError != nil {
                        print("Error saving record: \(String(describing: saveError?.localizedDescription))")
                    } else {
                        DispatchQueue.main.async {
                            self.view.window?.isDocumentEdited = false
                            self.doReload(nil)
                        }
                        //print("Successfully updated record!")
                    }
                })
            }
        })
    }
    
    @IBAction func reload(_ sender: Any?) {
        self.ifEditedSave()
        self.clearSelection()
        self.reloadFromiCloud(nil)
    }
    
    @IBAction func newDocument(_ sender: Any?) {
        // code to execute for open functionality here
        // following line prints in debug to show function is executing.
        // delete print line below when testing is completed.
        //print("New! \(self.objects.count)")
        self.clearSelection()
        let newOne = CKRecord(recordType: TDRecordTypeString)
        newOne[TDRecordKey.title] = ""
        
        newOne[TDRecordKey.body] = ""
        objects.insert(newOne, at: 0)
        container.privateCloudDatabase.save(newOne) { [unowned self] _, error in
            guard error == nil else {print("\(String(describing: error))"); return}
            DispatchQueue.main.async {
                self.doReload(newOne)
                //print("New, reloading \(self.objects.count)")
//                let indexSet = NSIndexSet(index: 1)
//                self.tableView.selectRowIndexes(indexSet as IndexSet, byExtendingSelection: false)
            }
        }
    }

    //MARK: - NSTableViewDelegate
    func tableViewColumnDidResize(_ notification: Notification) {
        let allIndexes = IndexSet(integersIn: 0..<tableView.numberOfRows)
        tableView.noteHeightOfRows(withIndexesChanged: allIndexes)
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard let tableCellView = tableViewCellForSizing else { return 30.0 }
        
        if let dataSource = tableView.dataSource as? NSTableViewSectionDataSource {
            let (section, sectionRow) = dataSource.tableView(tableView, sectionForRow: row)
            if sectionRow == 0 {
                return 30.0
            }
            //print(row, section, sectionRow-1)
            let object = sectionSource[section].items[sectionRow-1]
            tableCellView.textField?.preferredMaxLayoutWidth = tableView.tableColumns[0].width
            tableCellView.textField?.attributedStringValue = NSAttributedString(string: (object[TDRecordKey.body] as! String?)! + "\n| \(self.dateFormater.string(from: object.modificationDate!))")
            if let height = tableCellView.textField?.fittingSize.height, height > 0 {
                return height
            }
        }

        
        return 30.0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "CellView"), owner: self) as! NSTableCellView
        
        if let dataSource = tableView.dataSource as? NSTableViewSectionDataSource {
            let (section, sectionRow) = dataSource.tableView(tableView, sectionForRow: row)
            
            if let headerView = self.tableView(tableView, viewForHeaderInSection: section) as? NSTableCellView, sectionRow == 0 {
                if let value = dataSource.tableView!(tableView, objectValueFor: tableColumn, row: row) as? String {
                    headerView.textField?.stringValue = value
                }
                return headerView
            }
        }
        
        if let dataSource = tableView.dataSource as? NSTableViewSectionDataSource,
            let value = dataSource.tableView!(tableView, objectValueFor: tableColumn, row: row) as? String {
            cellView.textField?.stringValue = value
        }
        return cellView
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if let dataSource = tableView.dataSource as? NSTableViewSectionDataSource {
            let (_, sectionRow) = dataSource.tableView(tableView, sectionForRow: row)
            
            if sectionRow == 0 {
                return false
            }
            self.textView.isEditable = true
            return true
        }
        return false
    }

//    func tableViewSelectionIsChanging(_ notification: Notification) {
//        print("tableViewSelectionIsChanging")
//        //self.ifEditedSave()
//    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if let realTable = notification.object as? NSTableView {
            // create an [Int] array from the index set
            let selected = realTable.selectedRowIndexes.map({ Int($0) })
            if let dataSource = tableView.dataSource as? NSTableViewSectionDataSource {
                if selected.count > 0 {
                    self.selectedRow = selected[0]
                    let (section, sectionRow) = dataSource.tableView(tableView, sectionForRow: self.selectedRow!)
                    //print(selected, section, sectionRow-1)
                    self.selectedRecord = sectionSource[section].items[sectionRow-1]
                    self.textView.string = self.selectedRecord![TDRecordKey.body]  as! String
                } else {
                    self.clearSelection()
                }
            }
        }
    }
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        if let dataSource = tableView.dataSource as? NSTableViewSectionDataSource {
            var (section, sectionRow) = dataSource.tableView(tableView, sectionForRow: row)
            
            if let _ = self.tableView(tableView, viewForHeaderInSection: section) {
                if sectionRow == 0 {
                    return sectionSource[section].header as AnyObject
                } else {
                    sectionRow -= 1
                }
            }
            
            let object = sectionSource[section].items[sectionRow]
            
            return (object[TDRecordKey.body] as! String?)! + "\n| \(self.dateFormater.string(from: object.modificationDate!))" as AnyObject
        }
        return nil
    }

    func reloadFromiCloud(_ newRecord: CKRecord?) {
        self.objects.removeAll()
        if newRecord != nil {
            self.objects.append(newRecord!) // stitch in newOne
        }
        
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
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let queryOperation = CKQueryOperation (query: query)
        
        queryOperation.recordFetchedBlock = doneOneRecord
        
        queryOperation.queryCompletionBlock = {
            queryCursor, error in
            if error != nil {
                DispatchQueue.main.async {
                    print("queryCompletionBlock error: \(String(describing: error!))")
                }
            }
        }
        
        queryOperation.completionBlock = {
            //print("query Done. completionBlock: records found:\(self.objects.count)")
            
            DispatchQueue.main.async {
                self.performDateGrouping()
                self.tableView.reloadData()
                if self.oldSelectedRow != nil && newRecord == nil {
                    //print("attempting select of row \(self.oldSelectedRow!)")
                    self.tableView.selectRowIndexes(NSIndexSet(index: self.oldSelectedRow!) as IndexSet, byExtendingSelection: false)
                    self.textView.isEditable = true
                }
            }
        }
        container
            .privateCloudDatabase.add(queryOperation)
        
        
    }
    
    func performDateGrouping() {
        sectionFormater.dateFormat = self.sectionHeaderFormat
        if objects.count > 0 {
            var lastDate = (self.currentOrderby == ViewController.creationOrderby) ? (objects[0].creationDate)!: (objects[0].modificationDate)!
            //(objects[0].creationDate)! as Date
            var lastGroup = SectionOfCKRecord(header: sectionFormater.string(from: lastDate as Date), items: [])
            var dateGroups = [SectionOfCKRecord]()
            let calendar = NSCalendar.current
            
            self.sectionSource.removeAll()
            for element in objects {
                let currentDate = (self.currentOrderby == ViewController.creationOrderby) ? element.creationDate!: element.modificationDate!
                //element.creationDate!
                let unitFlags : Set<Calendar.Component> = [.era, .day, .month, .year, .hour, .minute, .timeZone]
                let difference = calendar.dateComponents(unitFlags, from: lastDate, to: currentDate)
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
    
}


//MARK: - NSTableViewSectionDelegate
protocol NSTableViewSectionDelegate: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewForHeaderInSection section: Int) -> NSView?
}

extension ViewController: NSTableViewSectionDelegate {
    func tableView(_ tableView: NSTableView, viewForHeaderInSection section: Int) -> NSView? {
        let sectionView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "SectionView"), owner: self) as! NSTableCellView
            return sectionView
    }
}

//MARK: - NSTableViewSectionDataSource
protocol NSTableViewSectionDataSource: NSTableViewDataSource {
    func numberOfSectionsInTableView(_ tableView: NSTableView) -> Int
    func tableView(_ tableView: NSTableView, numberOfRowsInSection section: Int) -> Int
    func tableView(_ tableView: NSTableView, sectionForRow row: Int) -> (section: Int, row: Int)
}

extension ViewController: NSTableViewSectionDataSource {
    
    // Optional
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        var total = 0
        
        if let dataSource = tableView.dataSource as? NSTableViewSectionDataSource {
            for section in 0..<dataSource.numberOfSectionsInTableView(tableView) {
                total += dataSource.tableView(tableView, numberOfRowsInSection: section)
            }
        }
        
        return total
    }
    
    func numberOfSectionsInTableView(_ tableView: NSTableView) -> Int {
        return sectionSource.count
    }
    
    func tableView(_ tableView: NSTableView, numberOfRowsInSection section: Int) -> Int {
        var count = 0
        
        if let _ = self.tableView(tableView, viewForHeaderInSection: section) {
            count += 1
        }
        
        count += sectionSource[section].items.count
        
        return count
    }
    
    func tableView(_ tableView: NSTableView, sectionForRow row: Int) -> (section: Int, row: Int) {
        if let dataSource = tableView.dataSource as? NSTableViewSectionDataSource {
            let numberOfSections = dataSource.numberOfSectionsInTableView(tableView)
            var counts = [Int](repeating: 0, count: numberOfSections)
            
            for section in 0..<numberOfSections {
                counts[section] = dataSource.tableView(tableView, numberOfRowsInSection: section)
            }
            
            let result = self.sectionForRow(row: row, counts: counts)
            return (section: result.section ?? 0, row: result.row ?? 0)
        }
        
        assertionFailure("Invalid datasource")
        return (section: 0, row: 0)
    }
    
    private func sectionForRow(row: Int, counts: [Int]) -> (section: Int?, row: Int?) {
        //let total = counts.reduce(0, {$0 + $1})
        
        var c = counts[0]
        for section in 0..<counts.count {
            if (section > 0) {
                c = c + counts[section]
            }
            if (row >= c - counts[section]) && row < c {
                return (section: section, row: row - (c - counts[section]))
            }
        }
        
        return (section: nil, row: nil)
    }
}
