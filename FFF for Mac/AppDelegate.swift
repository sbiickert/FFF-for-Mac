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
	
	static let unitsYMD: Set<Calendar.Component> = [.month, .year, .day]
	static let unitsYM: Set<Calendar.Component> = [.month, .year]

	var currentDate = Date() {
		didSet {
			let oldComponents = Calendar.current.dateComponents(AppDelegate.unitsYMD, from: oldValue)
			let newComponents = Calendar.current.dateComponents(AppDelegate.unitsYMD, from: currentDate)

			if oldComponents.year! == newComponents.year! && oldComponents.month! == newComponents.month! {
				NotificationCenter.default.post(name: NSNotification.Name(Notifications.CurrentDayChanged.rawValue), object: self)
			}
			else {
				NotificationCenter.default.post(name: NSNotification.Name(Notifications.CurrentMonthChanged.rawValue), object: self)
			}
		}
	}
	var currentDateComponents: (year:Int, month:Int, day:Int) {
		get {
			let components = Calendar.current.dateComponents(AppDelegate.unitsYMD, from: currentDate)
			return (year:components.year!, month:components.month!, day:components.day!)
		}
	}
	
	func setDayOfMonth(_ day:Int) {
		var components = Calendar.current.dateComponents(AppDelegate.unitsYMD, from: currentDate)
		components.setValue(day, for: .day)
		if let newDate = Calendar.current.date(from: components) {
			currentDate = newDate
		}
	}

	func application(_ sender: NSApplication, openFile filename: String) -> Bool {
		print("Opening file \(filename)")
		NotificationCenter.default.post(name: NSNotification.Name(Notifications.OpenBankFile.rawValue),
										object: self,
										userInfo: ["filename": filename])
		return true
	}
	
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		let defaults = UserDefaults.standard
		let storedUrl = defaults.string(forKey: DefaultsKey.ServerUrl.rawValue)
		if storedUrl == nil {
			defaults.set(RestGateway.shared.url, forKey: DefaultsKey.ServerUrl.rawValue)
		}
		
		// Update the list of transaction types
		CachingGateway.shared.getTransactionTypes() { message in
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

