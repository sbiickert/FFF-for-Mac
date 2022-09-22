//
//  CheckerDragView.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-06-15.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa

class CheckerDragView: NSView {

	var delegate: CheckerDragViewDelegate?
	
	required init?(coder decoder: NSCoder) {
		super.init(coder: decoder)
		setupDragging()
	}
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

		if isReceivingDrag {
			NSColor.selectedControlColor.set()
			
			let path = NSBezierPath(rect:bounds)
			path.lineWidth = 2.0
			path.stroke()
		}
		
	}
	
	private static var acceptableTypes: [NSPasteboard.PasteboardType] { return [NSPasteboard.PasteboardType.fileURL] }
	private func setupDragging() {
		registerForDraggedTypes(CheckerDragView.acceptableTypes)
	}
	
	
	
	/* mdls -name kMDItemContentTypeTree csv61973.csv
kMDItemContentTypeTree = (
"public.comma-separated-values-text",
"public.data",
"public.delimited-values-text",
"public.plain-text",
"public.item",
"public.content",
"public.text"
)
*/
	
	private let filteringOptions = [NSPasteboard.ReadingOptionKey.urlReadingContentsConformToTypes:["public.comma-separated-values-text"]]
	private func shouldAllowDrag(_ draggingInfo: NSDraggingInfo) -> Bool {
		var canAccept = false
		
		let pasteboard = draggingInfo.draggingPasteboard
		if pasteboard.canReadObject(forClasses: [NSURL.self], options: filteringOptions) {
			canAccept = true
		}
		
		return canAccept
	}
	
	private var isReceivingDrag = false {
		didSet {
			needsDisplay = true
		}
	}
	
	override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
		let allow = shouldAllowDrag(sender)
		isReceivingDrag = allow
		return allow ? .copy : NSDragOperation()
	}

	override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
		isReceivingDrag = false
		let pasteboard = sender.draggingPasteboard
		if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options:filteringOptions) as? [URL], urls.count > 0 {
			return delegate?.openCSV(urls.first!) ?? false
		}
		return false
	}
	override func draggingExited(_ sender: NSDraggingInfo?) {
		isReceivingDrag = false
	}
}

protocol CheckerDragViewDelegate {
	func openCSV(_ url:URL) -> Bool
}
