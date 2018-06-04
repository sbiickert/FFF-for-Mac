//
//  AppDelegate.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-02-13.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
	static let appVersion = "1.0.0"
	
	var currentDate = Date() {
		didSet {
			NotificationCenter.default.post(name: NSNotification.Name(Notifications.CurrentDateChanged.rawValue), object: self)
		}
	}
	var currentDateComponents: (year:Int, month:Int, day:Int) {
		get {
			let units: Set<Calendar.Component> = [.month, .year, .day]
			let components = Calendar.current.dateComponents(units, from: currentDate)
			return (year:components.year!, month:components.month!, day:components.day!)
		}
	}

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		let defaults = UserDefaults.standard
		let storedUrl = defaults.string(forKey: DefaultsKey.ServerUrl.rawValue)
		if storedUrl == nil {
			defaults.set(Gateway.defaultURL, forKey: DefaultsKey.ServerUrl.rawValue)
		}
		
		// Update the list of transaction types
		Gateway.shared.getTransactionTypes() { message in
			// Store in NSUserDefaults
			let eTypes = message.content[ResponseKey.ExpenseTypes.rawValue]
			let iTypes = message.content[ResponseKey.IncomeTypes.rawValue]
			DispatchQueue.main.async {
				UserDefaults.standard.set(eTypes, forKey: DefaultsKey.ExpenseTypes.rawValue)
				UserDefaults.standard.set(iTypes, forKey: DefaultsKey.IncomeTypes.rawValue)
			}
		}
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}


}

