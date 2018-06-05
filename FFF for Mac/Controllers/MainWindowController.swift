//
//  MainWindowController.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-02-17.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa

class MainWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate, NSSearchFieldDelegate {
	private let SpinnerToolbarItemID = NSToolbarItem.Identifier(rawValue: "Spinner")
	private let SearchToolbarItemID =  NSToolbarItem.Identifier(rawValue: "Search")
	private let DateToolbarItemID =  NSToolbarItem.Identifier(rawValue: "Date")

	@IBOutlet var spinner: NSProgressIndicator!
	@IBOutlet var datePicker: NSDatePicker!
	@IBOutlet var searchField: NSSearchField!
	
	private var tabViewController: NSTabViewController?
	
	private let titleDateFormatter = DateFormatter()

	var app:AppDelegate {
		get {
			return NSApplication.shared.delegate as! AppDelegate
		}
	}
	var currentDate: Date {
		get {
			return app.currentDate
		}
		set(value) {
			app.currentDate = value
		}
	}
	private var isTokenRequestInProgress = false
	{
		didSet {
			if isTokenRequestInProgress {
				spinner.startAnimation(self)
			}
			else {
				spinner.stopAnimation(self)
				// TODO: Request info for today's date
			}
		}
	}
	
    override func windowDidLoad() {
		
		// Automatic saving/restoring of window state
		shouldCascadeWindows = false
		window?.setFrameAutosaveName(NSWindow.FrameAutosaveName("FFF Main Window"))
		
        super.windowDidLoad()

		NotificationCenter.default.addObserver(self,
											   selector: #selector(loginNotificationReceived(_:)),
											   name: NSNotification.Name(rawValue: Notifications.LoginResponse.rawValue),
											   object: nil)

		NotificationCenter.default.addObserver(self,
											   selector: #selector(dateChangeNotificationReceived(_:)),
											   name: NSNotification.Name(rawValue: Notifications.CurrentDateChanged.rawValue),
											   object: nil)
		
		datePicker.dateValue = currentDate
		titleDateFormatter.dateStyle = .long
		window?.title = "Fantastic Fiduciary Friend - " + titleDateFormatter.string(from: app.currentDate)
		
		tabViewController = window?.contentViewController as? NSTabViewController
    }
	
	func customToolbarItem(itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, label: String, paletteLabel: String, toolTip: String, target: AnyObject, itemContent: AnyObject, action: Selector?) -> NSToolbarItem? {
		
		let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
		
		toolbarItem.label = label
		toolbarItem.paletteLabel = paletteLabel
		toolbarItem.toolTip = toolTip
		toolbarItem.target = target
		toolbarItem.action = action
		
		// Set the right attribute, depending on if we were given an image or a view.
		if (itemContent is NSImage) {
			let image: NSImage = itemContent as! NSImage
			toolbarItem.image = image
		}
		else if (itemContent is NSView) {
			let view: NSView = itemContent as! NSView
			toolbarItem.view = view
		}
		else {
			assertionFailure("Invalid itemContent: object")
		}
		return toolbarItem
	}
	
	func toolbarWillAddItem(_ notification: Notification) {
		// not used ATM
	}
	
	func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
		var toolbarItem: NSToolbarItem = NSToolbarItem()
		
		/* We create a new NSToolbarItem, and then go through the process of setting up its
		attributes from the master toolbar item matching that identifier in our dictionary of items.
		*/
		if (itemIdentifier == SearchToolbarItemID) {
			toolbarItem = customToolbarItem(itemForItemIdentifier: SearchToolbarItemID, label: "Search", paletteLabel: "Search", toolTip: "Search for transactions", target: self, itemContent: self.searchField, action: nil)!
		}
		else if (itemIdentifier == SpinnerToolbarItemID) {
			toolbarItem = customToolbarItem(itemForItemIdentifier: SpinnerToolbarItemID, label: "Waiting", paletteLabel: "Waiting", toolTip: "Waiting for a response", target: self, itemContent: self.spinner, action: nil)!
		}
		else if (itemIdentifier == DateToolbarItemID) {
			toolbarItem = customToolbarItem(itemForItemIdentifier: DateToolbarItemID, label: "Current Date", paletteLabel: "Current Date", toolTip: "Change the current date", target: self, itemContent: self.datePicker, action: nil)!
		}
		else if (itemIdentifier == NSToolbarItem.Identifier.flexibleSpace) {
			toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
		}
		
		return toolbarItem
	}
	
	func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		return [DateToolbarItemID, SpinnerToolbarItemID, NSToolbarItem.Identifier.flexibleSpace, SearchToolbarItemID]
	}
	
	func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		return [NSToolbarItem.Identifier.flexibleSpace, SearchToolbarItemID, SpinnerToolbarItemID, DateToolbarItemID]
	}
	
	func windowDidBecomeMain(_ notification: Notification) {
		// Check for valid user credentials
		if Gateway.shared.isLoggedIn == false {
			// Present modal sheet
			let loginWindowController = LoginWindowController(windowNibName: NSNib.Name("LoginWindowController"))
			window?.beginSheet(loginWindowController.window!, completionHandler: { responseCode in
				// User pressed OK. Submit credentials. Dismiss sheet if successful.
				// Store form values in defaults
				let u = loginWindowController.usernameTextField.stringValue.trimmingCharacters(in: CharacterSet.whitespaces)
				let p = loginWindowController.passwordTextField.stringValue.trimmingCharacters(in: CharacterSet.whitespaces)
				Gateway.setStoredCredentials(u, password: p)

				// Send off the request to the Gateway to log in
				Gateway.shared.login()
				self.isTokenRequestInProgress = true
				
				loginWindowController.window?.close()
			})
		}
	}
	
	@objc func loginNotificationReceived(_ notification: Notification) {
		// Ignore unless the login form is showing: it's a refetch of the token.
		isTokenRequestInProgress = false
	}
	
	@objc func dateChangeNotificationReceived(_ note: NSNotification) {
		datePicker.dateValue = currentDate
		window?.title = "Fantastic Fiduciary Friend - " + titleDateFormatter.string(from: app.currentDate)
	}

	func searchFieldDidStartSearching(_ sender: NSSearchField) {
		// TODO
		print("Starting to search for \(sender.stringValue)")
	}
	
	func searchFieldDidEndSearching(_ sender: NSSearchField) {
		// TODO
	}
	
	@IBAction func changeDate(_ sender: NSDatePicker) {
		currentDate = datePicker.dateValue
	}
	
	@IBAction func showCalendarMenuItemSelected(_ sender: Any) {
		tabViewController?.selectedTabViewItemIndex = 0
	}
	
	@IBAction func showListMenuItemSelected(_ sender: Any) {
		tabViewController?.selectedTabViewItemIndex = 1
	}
	
	@IBAction func showCategoriesMenuItemSelected(_ sender: Any) {
		tabViewController?.selectedTabViewItemIndex = 2
	}
	
	@IBAction func showCheckBankMenuItemSelected(_ sender: Any) {
		tabViewController?.selectedTabViewItemIndex = 3
	}
	
	//	func window(_ window: NSWindow, willEncodeRestorableState state: NSCoder) {
//		// Use encodeRestorableState(with: <#T##NSCoder#>)
//	}
//
//	func window(_ window: NSWindow, didDecodeRestorableState state: NSCoder) {
//		//
//	}
}
