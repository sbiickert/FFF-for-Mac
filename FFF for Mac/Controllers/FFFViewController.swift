//
//  FFFViewController.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-06-05.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa

class FFFViewController: NSViewController {
	var app:AppDelegate {
		get {
			return NSApplication.shared.delegate as! AppDelegate
		}
	}

	var currentDate:Date {
		get {
			return app.currentDate
		}
		set(value) {
			app.currentDate = value
		}
	}
	
	var tabViewController: NSTabViewController? {
		// Go up the containment stack until a tab view controller
		var vc:NSViewController = self
		while vc.parent != nil {
			if vc.parent! is NSTabViewController {
				return (vc.parent as! NSTabViewController)
			}
			vc = vc.parent!
		}
		return nil
	}
	
	func clearSelection() {}

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
//		NotificationCenter.default.addObserver(self,
//											   selector: #selector(loginNotificationReceived(_:)),
//											   name: .loginResponse,
//											   object: nil)
//		NotificationCenter.default.addObserver(self,
//											   selector: #selector(logoutNotificationReceived(_:)),
//											   name: .logoutResponse,
//											   object: nil)
		NotificationCenter.default.addObserver(self,
											   selector: #selector(currentDateChanged(_:)),
											   name: .currentMonthChanged,
											   object: nil)
		NotificationCenter.default.addObserver(self,
											   selector: #selector(currentDayChanged(_:)),
											   name: .currentDayChanged,
											   object: nil)
		NotificationCenter.default.addObserver(self,
											   selector: #selector(dataUpdated(_:)),
											   name: .dataUpdated,
											   object: nil)
		NotificationCenter.default.addObserver(self,
											   selector: #selector(dataRefreshed(_:)),
											   name: .dataRefreshed,
											   object: nil)
    }
	
	// MARK: Notifications
	
	@objc func loginNotificationReceived(_ notification: Notification) {}
	
	@objc func logoutNotificationReceived(_ notification: Notification) {}
	
	@objc func currentDateChanged(_ notification: Notification) {}
	
	@objc func currentDayChanged(_ notification: Notification) {}
	
	@objc func dataUpdated(_ notification: Notification) {}
	
	@objc func dataRefreshed(_ notification: Notification) {}

}
