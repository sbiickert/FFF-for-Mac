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
	var restGateway: Gateway!



	func applicationDidFinishLaunching(_ aNotification: Notification) {
		restGateway = Gateway()
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}


}

