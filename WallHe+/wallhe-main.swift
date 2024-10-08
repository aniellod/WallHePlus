//
//  main.swift
//  wallhe (requires MacOS 10.15+)
//
//  Swift 5
//
//  Created by Aniello Di Meglio on 2021-11-03.
//
//  Parts were converted to Swift 5.5 from Objective-C by Swiftify v5.5.22755 - https://swiftify.com/
//  Inspired by Wally by Antonio Di Monaco
//
//  Warning - very buggy and little error checking.
//
//  Requirements:
//      Swift-Image to handle .png:     https://github.com/koher/swift-image.git
//      Accessibility control to enable keyboard control of wallpaper
//
//  Very basic wallpaper controler for MacOS 10.15+
//
//  Specify image folder and delay, Wallhe will randomly pick an image, resize/tile it to fit all visible desktops then loop through all images.

//  Copyright (C) 2021 Aniello Di Meglio
//
//  MIT License

import Foundation
import SwiftUI
import SwiftImage // https://github.com/koher/swift-image.git

let theWork = thread2()
var errCounter: Int = 0
var previousFileURL: URL = URL(string: "http://dummy.url")!

class thread2 {
    var filelist: Array<String>
    var seconds: UInt32
    var currentImageFile: String
    var currentFullPath: [String]
    var count: Int
    var showInfo: Bool
    var subEnabled: Bool
    var thread: Thread
    var currentSelection: Int
    var pressedStop: Bool
    
    init() {
        self.seconds = 0
        self.filelist = []
        self.currentImageFile = ""
        self.currentFullPath = []
        self.count = 0
        self.showInfo = false
        self.subEnabled = false
        self.thread = Thread()
        self.currentSelection = 0
        self.pressedStop = false
        
        NSWorkspace.shared.notificationCenter.addObserver(self,
                                selector: #selector(spaceChanged),
                                name: NSWorkspace.activeSpaceDidChangeNotification,
                                object: nil)
        
        temporaryDirectoryURL.appendPathComponent("com.dimeglio.wallheplus")
        do {
            try FileManager().createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        } catch { errorMessage("Unable to create temporary directory.") }
    }
    
    @objc func spaceChanged() {
            // update wallpaper when user moved to another desktop space
            DispatchQueue.global().async {
                setBackground(theURL: previousFileURL.absoluteString)
            }
    }
    
    var subs: Bool {
        get { return subEnabled }
        set { subEnabled = newValue }
    }
    
    var fileList: Array<String> {
        get { return filelist }
        set { filelist = newValue }
    }
    
    var delay: UInt32 {
        get { return seconds }
        set { seconds = newValue }
    }
    
    var directory: [String] {
        get { return currentFullPath }
        set { currentFullPath = newValue }
    }
    
    var imageFile: String {
        get { return currentImageFile }
        set { currentImageFile = newValue }
    }
    
    var temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(),
                                        isDirectory: true)

    func addMoreFiles(sourceUrls: [URL], destUrls: [URL]) -> [URL] {
        return Array(Set(sourceUrls + destUrls))
    }

    func removeFiles(sourcePaths: [String], theURL: String) -> [String] {
        return sourcePaths.filter { !$0.contains(theURL) }
    }
    
    func errorMessage(_ value: String) {
        if let window = NSApp.keyWindow {
            let errorMessage = NSAlert()
            errorMessage.alertStyle = .critical
            errorMessage.messageText = "Error"
            errorMessage.informativeText = value
            errorMessage.addButton(withTitle: "Stop")
            errorMessage.beginSheetModal(for: window, completionHandler: nil)
        }
    }
    
    func load() {
        filelist.removeAll()
        filelist = buildFileList(directory)
        filelist.shuffle()
        count = 0
    }
    
    func start() {
        thread = Thread.init(target: self, selector: #selector(mainLoop), object: nil)
        thread.start()
    }
    
    func stop() {
        while thread.isExecuting {
            thread.cancel()
        }
    }
    
    func skip() {
        while thread.isExecuting {
            thread.cancel()
        }
        thread = Thread.init(target: self, selector: #selector(mainLoop), object: nil)
        thread.start()
    }
    
    @objc func mainLoop() {
        let initCount = filelist.count
        var countFlag = false
        if count >= filelist.count { thread.cancel(); return } //no images were found in initial pass or something weird is going on. Just bail for now.
        
        for i in count..<filelist.count {
            self.currentImageFile = filelist[i]
            self.count+=1
            let countString = String(self.count) + "/" + String(filelist.count) + " - "
            DispatchQueue.main.async { // add to the log window
                vc.addLogItem(countString + self.filelist[i])
                vc.fileName = self.filelist[i]
            }
            autoreleasepool { // needed to avoid memory leaks.
                updateWallpaper(fullPathToImage: filelist[i])
                currentSelection = i
            }
            for _ in 1..<seconds { // checks for cancellation every second
                sleep(1)
                if thread.isCancelled {
                    return
                }
            }
            if initCount != fileList.count { //if we have a new count, restart but continue from where we were.
                countFlag = true
                break
            }
        }
        if !countFlag {
            self.count = 0 //we're out of the loop, reset the count
        }
        self.start() //restart loop, otherwise this thread terminates.
    }
}

// setBackground: input=path to prepared image file. Updates the display with the new wallpaper on all screens.
func setBackground(theURL: String) {
    let workspace = NSWorkspace.shared
    let fixedURL = URL(string: theURL)
    var options = [NSWorkspace.DesktopImageOptionKey: Any]()
    options[.imageScaling] = NSImageScaling.scaleProportionallyUpOrDown.rawValue
    options[.allowClipping] = false
    let theScreens = NSScreen.screens
    
    for x in theScreens {
        do {
            try workspace.setDesktopImageURL(fixedURL!, for: x, options: options)
        } catch {
                print("\(#function) \(#line): Unable to update wallpaper!")
                vc.addLogItem("[\(#function) \(#line): unable to update wallpaper!]")
        }
    }
}

// buildWallpaper: input is the image; output is the tiled wallpaper ready to go.
func buildWallpaper(sample: NSImage, text: String...) -> NSImage {
    let textFont = NSFont(name: "Helvetica Bold", size: 18)!
    let textFontAttributes = [
        NSAttributedString.Key.font: textFont,
        NSAttributedString.Key.shadow: NSShadow(),
        NSAttributedString.Key.foregroundColor: NSColor.gray,
        NSAttributedString.Key.backgroundColor: NSColor.black
    ]
    
    var drawText=NSString(string: text[0])
    if !theWork.showInfo {
        drawText = ""
    }
    
    let screenSize = NSScreen.screenSize
    let sw = screenSize!.width
    let sh = screenSize!.height
    let tiles = Int(sw / sample.size.width)
    let resultImage = NSImage(size: (NSMakeSize(sw,sh)))
    
    resultImage.lockFocus()
    
    do {
        for x in 0...tiles {
            sample.draw(at: NSPoint(x: Int(sample.size.width) * x, y: 0),
                        from: NSRect.zero,
                        operation: NSCompositingOperation.sourceOver,
                        fraction: 1.0)
        }
        sample.draw(at: NSPoint(x: Int(sample.size.width) * tiles, y: 0),
                    from: NSRect(x: 0, y:0, width: (sw - sample.size.width * 2), height: sh),
                    operation: NSCompositingOperation.sourceOver, fraction: 1.0)
    }
    drawText.draw(at: NSPoint(x: 20, y: sh - 60), withAttributes: textFontAttributes)
    resultImage.unlockFocus()
    
    return resultImage
}

// resizedImage: input = URL of input image; size = new size of image; output = new resized image
func resizedImage(at url: URL, for size: CGSize) -> NSImage? {
    if url.path.lowercased().contains(".png") {
        let thisImage = SwiftImage.Image<RGB<UInt8>>(contentsOfFile: url.path)
        let result = thisImage?.resizedTo(width: Int(size.width), height: Int(size.height))
        let scaledImage = result?.nsImage
        return scaledImage
    } else { // this is faster but needs fix to handle reading and resizing png files.
        guard let imageSource = CGImageSourceCreateWithURL(url as NSURL, nil),
            let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else {
            return nil
        }
        
        let context = CGContext(data: nil,
                                width: Int(size.width),
                                height: Int(size.height),
                                bitsPerComponent: image.bitsPerComponent,
                                bytesPerRow: 0,
                                space: image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: image.bitmapInfo.rawValue)
        context?.interpolationQuality = .high
        autoreleasepool {
            context?.draw(image, in: CGRect(origin: .zero, size: size))
        } 
        guard let scaledImage = context?.makeImage() else { return nil }
        
        return NSImage(cgImage: scaledImage,
                       size: CGSize(width: size.width,height: size.height))
    }
}

// updateWallpaper: main function
// updateWallpaper: input path to image and check the image, resize, tile, and update the wallpaper.
func updateWallpaper(fullPathToImage: String) {
    if fullPathToImage.isEmpty { return } // exit if no name was provided
  //  let desktopURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first! // where to store tmp image file.
    let desktopURL = theWork.temporaryDirectoryURL  // where to store tmp image file.
    let destinationURL: URL = desktopURL.appendingPathComponent(URL(string: fullPathToImage)!.lastPathComponent)
    
    do {
        let fileToDeleteURL = previousFileURL
        try FileManager().removeItem(at: fileToDeleteURL)
    } catch { vc.addLogItem("[\(#function) \(#line): \(error.localizedDescription) @ \(previousFileURL)") }
    
    previousFileURL = destinationURL
    let theURL = URL(fileURLWithPath: fullPathToImage)
    let origImage = NSImage(contentsOf: theURL)
    guard let height = origImage?.size.height else {
        print("[\(#function) \(#line): Error in calculating height of image at \(fullPathToImage)")
        DispatchQueue.main.async {
            vc.addLogItem("[\(#function) \(#line): unable to process image \(fullPathToImage). Check path.]")
        }
        return
    }
    let ratio = NSScreen.screenHeight! / height
    let newWidth = (origImage!.size.width) * ratio

    guard let newImage = resizedImage(at: theURL, for: CGSize(width: newWidth, height: NSScreen.screenHeight!))
    else {
        print("[\(#function) \(#line): Error \(theURL) cannot be opened.")
        return
    }

    let finalImage = buildWallpaper(sample: newImage, text: fullPathToImage) // tiles and resizes newImage
    
    guard finalImage.pngWrite(to: destinationURL) else {
        print("File count not be saved")
        DispatchQueue.main.async {
            vc.addLogItem("[\(#function) \(#line): unable to save wallpaper]")
        }
        return
    }
    setBackground(theURL: (destinationURL.absoluteString))
}

func setUp(secondsDelay: Int, paths: [URL], subs: Bool) {
    theWork.subs = subs
    let seconds: UInt32 = UInt32(abs(Int(exactly: secondsDelay)!))
    theWork.delay = seconds
    theWork.directory = []
    for i in paths {
        theWork.directory.append(i.path)
        print ("path = \(i.path)")
    }
    theWork.load()
}

func buildFileList(_ pathsToSearch: [String]) -> Array<String> {
    var theFilelist: Array<String> = []
    theFilelist = getSubDirs(pathsToSearch)
    
    if theFilelist.count == 0 {
        vc.stop("_Any_")
        theWork.stop()
        theWork.errorMessage("[\(#function) \(#line): Error: No images found in directory \(pathsToSearch)")
    }
    return theFilelist
}

func getSubDirs(_ pathsToSearch: [String]) -> Array<String> { // Specify the root of the directory tree to be traversed.
    let filemgr = FileManager.default
    var count = 0
    let randNo = Int.random(in: 20..<100)
    var subFolders: Array<String>! = []
    
    let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey, .localizedLabelKey, .tagNamesKey])
    let options: FileManager.DirectoryEnumerationOptions = theWork.subs == true
                    ? [.skipsHiddenFiles]
                    : [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
    var enumerator = FileManager.DirectoryEnumerator()
    
    for pathToSearch in pathsToSearch {  // obtain a small sample of images to begin the rotation.
        enumerator = filemgr.enumerator(at: URL(fileURLWithPath: pathToSearch), includingPropertiesForKeys: Array(resourceKeys), options: options)!
        for case let name as URL in enumerator {
            do {
                let properties = try name.resourceValues(forKeys: resourceKeys)
                if properties.isDirectory! ||
                    (properties.tagNames?.description.lowercased().contains("private")) ??
                    false { continue } // skip directories
            } catch { print(error) }
            subFolders.append(name.path)
            if count==randNo { break }  //exit the loop at a random point
            count+=1
        }
    }
    
    count = 0
    var theFilelist: [String] = []
    let queue = DispatchQueue(label: "on.paths.")
    var tokens: [Substring] = []
    tokens = vc.tokenField(vc.tokenFilter) ?? [""]
    
    queue.async {
        for pathToSearch in pathsToSearch {  // Build array with all file paths so we can pick some random ones out of the list
            enumerator = filemgr.enumerator(at: URL(fileURLWithPath: pathToSearch), includingPropertiesForKeys: Array(resourceKeys), options: options)!
            DispatchQueue.main.async {  vc.startAnimation() }
            for case let name as URL in enumerator {
                if (theWork.pressedStop) { break }
                do {
                    let properties = try name.resourceValues(forKeys: resourceKeys)
                    if ((properties.tagNames?.description.lowercased().contains("private")) ?? false ) {
                        continue } // skip this image
                } catch { print(error) }
                theFilelist.append(name.path)
            }
        }
        
        print(theFilelist.count)
        for badone in [".mp4", ".log", ".csv", ".mov", ".avi"] {
            theFilelist = theFilelist.filter{ !($0.lowercased().contains(badone.lowercased())) }
        }

        for filter in tokens {
            print("filtering \(filter)")
            theFilelist = theFilelist.filter{ !($0.lowercased()).contains(filter.lowercased()) }
        }
        print(theFilelist.count)
        
        if theFilelist.count > 10000 {  // grab 10000 random images
            for _ in 1..<theFilelist.count-10000 {
                if (theWork.pressedStop) { theWork.pressedStop = false; break }
                theFilelist.remove(at: Int.random(in: 0..<theFilelist.count))
            }
        }
        
        for (index, name) in theFilelist.enumerated() { // check to remove non-image files
            var isDir : ObjCBool = false
            let x = FileManager.default
            if x.fileExists(atPath: name, isDirectory:&isDir) {
                if !isDir.boolValue && NSImage(contentsOfFile: name) != nil  { // weed out non-image files and directories
                    subFolders.append(name)
                } else { print("Is not an image: \(name)") }
            }
            if index % 500 == 0 { theWork.fileList = subFolders.shuffled() }
            if (theWork.pressedStop) { theWork.pressedStop = false; break }
        }
        theWork.fileList = subFolders.shuffled()
        DispatchQueue.main.async { vc.stopAnimation() }
    }
    return subFolders ?? ["/"]
}

func getSubDirs2(_ pathsToSearch: [String]) -> Array<String> { // Specify the root of the directory tree to be traversed.
    let filemgr = FileManager.default
    var count = 0
    let randNo = Int.random(in: 20..<100)
    var subFolders: Array<String>! = []
    
    let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey, .localizedLabelKey, .tagNamesKey])
    let options: FileManager.DirectoryEnumerationOptions = theWork.subs == true
                    ? [.skipsHiddenFiles]
                    : [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
    var enumerator = FileManager.DirectoryEnumerator()
    
    for pathToSearch in pathsToSearch {  // obtain a small sample of images to begin the rotation.
        enumerator = filemgr.enumerator(at: URL(fileURLWithPath: pathToSearch), includingPropertiesForKeys: Array(resourceKeys), options: options)!
        for case let name as URL in enumerator {
            do {
                let properties = try name.resourceValues(forKeys: resourceKeys)
                if properties.isDirectory! ||
                    (properties.tagNames?.description.lowercased().contains("private")) ??
                    false { continue } // skip directories
            } catch { print(error) }
            subFolders.append(name.path)
            if count==randNo { break }  //exit the loop at a random point
            count+=1
        }
    }
    
    count = 0
    var theFilelist: [String] = []
    let queue = DispatchQueue(label: "on.paths.")
    var tokens: [Substring] = []
    tokens = vc.tokenField(vc.tokenFilter) ?? [""]
    
    queue.async {
        for pathToSearch in pathsToSearch {  // Build array with all file paths so we can pick some random ones out of the list
            enumerator = filemgr.enumerator(at: URL(fileURLWithPath: pathToSearch), includingPropertiesForKeys: Array(resourceKeys), options: options)!
            DispatchQueue.main.async {  vc.startAnimation() }
            for case let name as URL in enumerator {
                if (theWork.pressedStop) { break }
                do {
                    let properties = try name.resourceValues(forKeys: resourceKeys)
                    if ((properties.tagNames?.description.lowercased().contains("private")) ?? false ) {
                        continue } // skip this image
                } catch { print(error) }
                theFilelist.append(name.path)
                
            }
        }
        
        print(theFilelist.count)
        for badone in [".mp4", ".log", ".csv", ".mov", ".avi"] {
            theFilelist = theFilelist.filter{ !($0.lowercased().contains(badone.lowercased())) }
        }

        for filter in tokens {
            print("filtering \(filter)")
            theFilelist = theFilelist.filter{ !($0.lowercased()).contains(filter.lowercased()) }
        }
        print(theFilelist.count)
        
        if theFilelist.count > 10000 {  // grab 10000 random images
            for _ in 1..<theFilelist.count-10000 {
                if (theWork.pressedStop) { theWork.pressedStop = false; break }
                theFilelist.remove(at: Int.random(in: 0..<theFilelist.count))
            }
        }
        
        for name in theFilelist {  // check to remove non-image files
            var isDir : ObjCBool = false
            let x = FileManager.default
            if x.fileExists(atPath: name, isDirectory:&isDir) {
                if !isDir.boolValue && NSImage(contentsOfFile: name) != nil  { // weed out non-image files and directories
                    subFolders.append(name)
                } else { print("Is not an image: \(name)") }
            }
        }
        DispatchQueue.main.async { vc.stopAnimation() }
    }
    return subFolders ?? ["/"]
}

class saveReadJson {
    
    private var path:[URL]
    private var theFileName:URL
    
    init() {
        path = []
        theFileName = URL(string: "/tmp/file.json")!
    }
    
    var pathToSave: [URL] {
        get { return path }
        set { path = newValue }
    }
    
    var fullyQualifiedFileName: URL {
        get { return theFileName }
        set { theFileName = newValue }
    }
    
    func saveDocumentDirectory() {
        let filePath = getFilename()
        if filePath != nil {
            let levels = pathToSave
            let json = try? JSONEncoder().encode(levels)
            do {
                 try json!.write(to: filePath!)
                     fullyQualifiedFileName = filePath!
            } catch {
                print("Failed to write JSON data: \(error.localizedDescription)")
            }
        }
    }
    
    func saveExisting() {
        if FileManager().fileExists(atPath: fullyQualifiedFileName.path) {
            print("pathtosave:\(pathToSave) \nfully:\(fullyQualifiedFileName)")
            let json = try? JSONEncoder().encode(pathToSave)
            do {
                 try json!.write(to: fullyQualifiedFileName)
            } catch {
                print("Failed to write JSON data: \(error.localizedDescription)")
            }
        }
    }
    
    func openDocument() -> [URL] {
        let fileName = getDocument()
        if fileName == nil { return [] }
        do {
            fullyQualifiedFileName = fileName!
            let data = try Data(contentsOf: fileName!, options: .mappedIfSafe)
            let decoder = JSONDecoder()
            let paths: [URL] = try! decoder.decode([URL].self, from: data)
            return paths
        } catch { print("\(error)") }
        return []
    }
    
    private func getDocument() -> URL? {
        let dialog = NSOpenPanel();
        dialog.title                   = "Choose file";
        dialog.showsResizeIndicator    = true;
        dialog.showsHiddenFiles        = false;
        dialog.allowsMultipleSelection = false;
        dialog.canChooseDirectories = false
        dialog.canChooseFiles = true
        
        if (dialog.runModal() ==  NSApplication.ModalResponse.OK) {
            let result = dialog.url! // Pathname of the file
            print("Result = \(String(describing: result))")
            if (!result.pathComponents.isEmpty) {
                return result
            }
        }
        // "Cancel" was clicked
        return nil //URL(string: "/")!
    }
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func getFilename() -> URL? {
        let dialog = NSSavePanel()
        dialog.title = "Save set to:"
        dialog.canCreateDirectories = true
        dialog.directoryURL = getDocumentsDirectory()
        dialog.runModal()
        print("dialog.url = \(String(describing: dialog.url!))")
        return dialog.url
    }
    
    private func append(toPath path: String, withPathComponent pathComponent: String) -> String? {
        if var pathURL = URL(string: path) {
            pathURL.appendPathComponent(pathComponent)
            
            return pathURL.absoluteString
        }
        
        return nil
    }
}
