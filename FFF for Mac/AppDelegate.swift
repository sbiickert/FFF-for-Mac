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
	static let defaultURL = "https://www.biickert.ca/FFF4/services/web/app.php"
	
	var restGateway = Gateway()



	func applicationDidFinishLaunching(_ aNotification: Notification) {
		let defaults = UserDefaults.standard
		let storedUrl = defaults.string(forKey: DefaultsKey.ServerUrl.rawValue)
		if storedUrl == nil {
			defaults.set(AppDelegate.defaultURL, forKey: DefaultsKey.ServerUrl.rawValue)
		}
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}


}

