//
//  MainSplitViewController.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-02-17.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa

class MainSplitViewContainerController: FFFViewController {

	override func clearSelection() {
		for child in childViewControllers {
			if let svc = child as? NSSplitViewController {
				for svi in svc.splitViewItems {
					if let fffController = svi.viewController as? FFFViewController {
						fffController.clearSelection()
					}
				}
			}
		}
	}
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
}
