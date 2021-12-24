//
//  ViewController.swift
//  WallHe+
//
//  Created by Aniello Di Meglio on 2021-11-11.
//
//  Copyright (C) 2021 Aniello Di Meglio
//
//  MIT License

import Cocoa
import SwiftUI

class ViewController: NSViewController {
    @IBOutlet weak var delaySelect: NSPopUpButton!
    @IBOutlet var okButton: NSButtonCell!
    @IBOutlet var stopButton: NSButton!
    @IBOutlet var skipButton: NSButton!
    @IBOutlet var showInfoBox: NSButton!
    @IBOutlet weak var doSubDirectories: NSButton!
    @IBOutlet weak var progress: NSProgressIndicator!
    @IBOutlet weak var loadingText: NSTextField!
    @IBOutlet weak var imageDisplayed: NSTextField!
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var selectedButton: NSSegmentedControl!
    
    @IBOutlet weak var column0: NSTableColumn!
    @IBOutlet weak var headerView: NSTableHeaderView!
    
//    //  Converted to Swift 5.5 by Swiftify v5.5.17943 - https://swiftify.com/
//    override func awakeFromNib() {
//        var frame = tableView.headerView?.frame
//        frame?.size.height = 26
//        tableView.headerView?.frame = frame ?? NSRect.zero
//    }
    
    var showInfo : Bool = false
    var isRunning : Bool = false
    var menuSelect : Int = 2
    var delay: Int = 0
   // var path: [URL] = []
    var lePopOver = NSPopover()
    var data: NSMutableArray = NSMutableArray()
    var booboo = ""
    var tokenFilter:NSTokenField = NSTokenField()
    
    @objc dynamic var nameList: [URL] = [URL(string: "/value")!]
    
    @IBAction func infoToggle(_ sender: NSButton) {
        setInfo()
    }
    
    func tokenField(_ tokenFieldArg: NSTokenField) -> [Substring]? {
        let valueNames: String = String(tokenFieldArg.stringValue as String)
        let valueArray = valueNames.split(separator: ",")
        return valueArray
    }
    
    func setInfo() {
        if showInfoBox.state == .off {
            showInfo = false
            theWork.showInfo = false
        } else {
            showInfo = true
            theWork.showInfo = true
        }
        updateWallpaper(name: theWork.imageFile)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        var theTableView = column0.tableView
        theTableView?.headerView?.frame
        //setup the log window so each line doesn't wrap around
        //logData.maxSize = NSMakeSize(CGFloat(Float.greatestFiniteMagnitude), CGFloat(Float.greatestFiniteMagnitude))
        //logData.isHorizontallyResizable = true
        //logData.textContainer?.widthTracksTextView = false
        //logData.textContainer?.containerSize = NSMakeSize(CGFloat(Float.greatestFiniteMagnitude), CGFloat(Float.greatestFiniteMagnitude))
   
        nameList.remove(at: 0)
        stopButton.isEnabled = false
        okButton.isEnabled = true
        delaySelect.removeAllItems()
        progress.isHidden = true
        delaySelect.addItems(withTitles:
                                ["Every 5 seconds",
                                 "Every minute",
                                 "Every 5 minutes",
                                 "Every 15 minutes",
                                 "Every 30 minutes",
                                 "Every hour",
                                 "Every day"
                                ])
        loadDefaults()
        self.delay = getSeconds(selection: menuSelect)
        if isRunning {
            stopButton.isEnabled = true
            skipButton.isEnabled = true
            setUp(secondsDelay: delay, paths: nameList, subs: (doSubDirectories.state == .on ? true : false))
            okButton.isEnabled = false
            stopButton.title = "Stop"
            theWork.start()
        }
    }
    
    func addLogItem(_ fileName: String) {
        let formatter = DateFormatter()
        let now = Date()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        let date = formatter.string(from: now)
        //logData.isEditable = true
        //logData.textStorage?.append(NSAttributedString(string: date + " - " + fileName + "\n"))
        //logData.isEditable = false
        logValue = logValue + "\(date) - \(fileName)\n"
    }
    
    func saveDefaults() {
        let mySettings = UserDefaults.standard
        mySettings.set(delaySelect.indexOfSelectedItem, forKey: "menuSelect")
        let nameListStore = URLarrayToStringArray(url: nameList)
        mySettings.set(nameListStore, forKey: "path")
        mySettings.set(showInfo, forKey: "showinformation")
        mySettings.set(isRunning, forKey: "isRunning")
        mySettings.set(theWork.count, forKey: "count")
        mySettings.set(doSubDirectories.state, forKey: "subdirs")
        mySettings.set(tokenField(tokenFilter), forKey: "filter")
    }
    
    func loadDefaults() {
        let mySettings = UserDefaults.standard
        menuSelect = mySettings.object(forKey: "menuSelect") as? Int ?? 2
        delaySelect.select(delaySelect.menu?.item(at: menuSelect))
        let nameListStore = mySettings.object(forKey: "path")
        nameList = StringArrayToURLArray(strings: nameListStore as? [String] ?? [FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!.path])
        displaySelectedFolders()
        showInfo = mySettings.bool(forKey: "showinformation")
        showInfoBox.state = showInfo == true ? .on : .off
        setInfo()
        theWork.count = mySettings.object(forKey: "count") as? Int ?? 0
        isRunning = mySettings.bool(forKey: "isRunning")
        stopButton.title = "Start"
        doSubDirectories.state = mySettings.object(forKey: "subdirs") as? NSButton.StateValue ?? .off
        let token: [Substring] = mySettings.object(forKey: "filter") as? [Substring] ?? [""]
        tokenFilter.stringValue=token.joined(separator: ",")
        print("tokenFilter: \(tokenFilter.stringValue)")
    }
    
    var fileName: String {
        get { return imageDisplayed.stringValue }
        set { imageDisplayed.stringValue = newValue }
    }
    
    func displaySelectedFolders() {
        var folder: String = ""
        for path in nameList {
            folder = folder + "\n" + path.path
        }
        addLogItem(folder)
        //avc.addLogItem(folder)
    }
    
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    func getFileName() -> [URL] {
        let dialog = NSOpenPanel();
        dialog.title                   = "Choose folder";
        dialog.showsResizeIndicator    = true;
        dialog.showsHiddenFiles        = false;
        dialog.allowsMultipleSelection = true;
        dialog.canChooseDirectories = true
        dialog.canChooseFiles = false
        
        if (dialog.runModal() ==  NSApplication.ModalResponse.OK) {
            let result = dialog.urls // Pathname of the file
            print("Result = \(result)")
//            var selectedPath: Array<String> = []
            if (result.count != 0) {
//                for path in result {
//                    selectedPath.append(path.path)
//                }
                return result
            }
        }
            // User clicked on "Cancel"
            return []
    }

    @IBAction func selectPath(_ sender: Any) {
        nameList = getFileName()
    }
    
    @IBAction func showInFinder(_ sender: Any) {
        if theWork.filelist.count > 0 {
        let url = URL(fileURLWithPath: theWork.filelist[theWork.currentSelection])
        do {
            if try url.checkResourceIsReachable() {
                NSWorkspace.shared.activateFileViewerSelecting([url])
                return
            }
        } catch { return }
        }
    }
    
    
    @IBAction func Ok(_ sender: Any) {  //load button
        for value in tokenField(tokenFilter) ?? [""] {
            print(value)
        }
        theWork.pressedStop = false
        errCounter = 0
        stopButton.isEnabled = true
        skipButton.isEnabled = true
        displaySelectedFolders()
        setUp(secondsDelay: delay, paths: nameList,subs: (doSubDirectories.state == .on ? true : false))
    }
    
    @IBAction func exitApp(_ sender: Any) {
        theWork.stop()
        stopAnimation()
        saveDefaults()
        exit(0)
    }
    
    @IBAction func stop(_ sender: Any) {
        let type = sender is NSButton
        var typeCheck: String = ""
        if type == false { //if the call is not from a button, it is a string.
            typeCheck = sender as! String
        }

        if isRunning {
            okButton.isEnabled = true
            stopButton.title = "Start"
            skipButton.isEnabled = false
            theWork.pressedStop = true
            isRunning = false
            theWork.stop()
        } else {
            okButton.isEnabled = false
            stopButton.title = "Stop"
            skipButton.isEnabled = true
            theWork.start()
            theWork.pressedStop = false
            isRunning = true
        }

        if typeCheck == "_Any_" {
            okButton.isEnabled = true
            stopButton.title = "Start"
            stopButton.isEnabled = false
            skipButton.isEnabled = false
            theWork.stop()
            isRunning = false
        }
        saveDefaults()
    }
    
    @IBAction func selectDelay(_ sender: Any) {
        self.delay = getSeconds(selection: delaySelect.indexOfSelectedItem)
        theWork.seconds = UInt32(self.delay)
        saveDefaults()
    }
    
    @IBAction func addRemove(_ sender: Any) {
        if selectedButton.selectedSegment == 0 {
            nameList = Array(Set(nameList + getFileName()))
        }
        if selectedButton.selectedSegment == 1 {
            if tableView.numberOfRows > 0 && tableView.selectedRow > -1 {
                //  https://stackoverflow.com/questions/59868180/swiftui-indexset-to-index-in-array
                tableView.selectedRowIndexes.sorted(by: > ).forEach { (i) in
                    nameList.remove(at: i)
                }
            }
        }
    }
    
    func URLarrayToStringArray(url: [URL]) -> [String] {
        var stringArray:[String] = []
        for i in url {
            stringArray.append(i.path)
        }
        return stringArray
    }
    
    func StringArrayToURLArray(strings: [String]) -> [URL] {
        var URLArray:[URL] = []
        for i in strings {
            URLArray.append(URL(string: i)!)
        }
        return URLArray
    }
    
    func getSeconds(selection: Int) -> Int {
        var secs = 0
        switch selection {
        case 0:
            secs = 5
        case 1:
            secs = 1 * 60
        case 2:
            secs = 5 * 60
        case 3:
            secs = 15 * 60
        case 4:
            secs = 30 * 60
        case 5:
            secs = 60 * 60
        case 6:
            secs = 60 * 24 * 60
        default:
            secs = 5 * 60
        }
        return secs
    }
    
    @IBAction func nextImage(_ sender: NSButton) {
        theWork.skip()
    }
    
    func startAnimation() {
        progress.isHidden = false
        loadingText.isHidden = false
        progress.startAnimation(nil)
    }
    
    func stopAnimation() {
        progress.stopAnimation(nil)
        progress.isHidden = true
        loadingText.isHidden = true
    }
}
