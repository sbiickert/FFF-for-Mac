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

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		let defaults = UserDefaults.standard
		let storedUrl = defaults.string(forKey: DefaultsKey.ServerUrl.rawValue)
		if storedUrl == nil {
			defaults.set(Gateway.defaultURL, forKey: DefaultsKey.ServerUrl.rawValue)
		}
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}


}

