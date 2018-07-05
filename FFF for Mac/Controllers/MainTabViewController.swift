//
//  MainTabViewController.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-07-05.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa

class MainTabViewController: NSTabViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
	
	override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
		super.tabView(tabView, didSelect: tabViewItem)
		
		// Clear any selected transaction on the other tabViewItems
		for tvi in tabViewItems {
			if tvi != tabViewItem {
				if let fffController = tvi.viewController as? FFFViewController {
					fffController.clearSelection()
				}
			}
		}
	}
}
