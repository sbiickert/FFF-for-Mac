//
//  DetailTableCellView.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-02-18.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa

class DetailTableCellView: NSTableCellView {
	@IBOutlet weak var iconImageButton: NSButton!
	@IBOutlet weak var transactionTypeNameLabel: NSTextField!
	@IBOutlet weak var amountLabel: NSTextField!
	@IBOutlet weak var descriptionLabel: NSTextField!
	
	@IBAction func iconButtonClicked(_ sender: NSButton) {
	}
	
	override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
}
