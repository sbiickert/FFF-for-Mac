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
	private let AddToolbarItemID =  NSToolbarItem.Identifier(rawValue: "Add")
	private let BalanceToolbarItemID =  NSToolbarItem.Identifier(rawValue: "Balance")

	@IBOutlet var spinner: NSProgressIndicator!
	@IBOutlet var datePicker: NSDatePicker!
	@IBOutlet var searchField: NSSearchField!
	@IBOutlet var addButton: NSButton!
	@IBOutlet var monthBalance: MonthBalanceView!
	
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
											   selector: #selector(logoutNotificationReceived(_:)),
											   name: NSNotification.Name(rawValue: Notifications.LogoutResponse.rawValue),
											   object: nil)

		NotificationCenter.default.addObserver(self,
											   selector: #selector(dateChangeNotificationReceived(_:)),
											   name: NSNotification.Name(rawValue: Notifications.CurrentMonthChanged.rawValue),
											   object: nil)

		NotificationCenter.default.addObserver(self,
											   selector: #selector(transactionEditRequest(_:)),
											   name: NSNotification.Name(rawValue: Notifications.ShowEditForm.rawValue),
											   object: nil)

		NotificationCenter.default.addObserver(self,
											   selector: #selector(dataUpdated(_:)),
											   name: NSNotification.Name(rawValue: Notifications.DataUpdated.rawValue),
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
		else if (itemIdentifier == AddToolbarItemID) {
			toolbarItem = customToolbarItem(itemForItemIdentifier: AddToolbarItemID, label: "Add Transaction", paletteLabel: "Add", toolTip: "Create a new transaction", target: self, itemContent: self.addButton, action: nil)!
		}
		else if (itemIdentifier == BalanceToolbarItemID) {
			toolbarItem = customToolbarItem(itemForItemIdentifier: BalanceToolbarItemID, label: "Balance", paletteLabel: "Balance", toolTip: "Monthly balance", target: self, itemContent: self.monthBalance, action: nil)!
		}
		else if (itemIdentifier == NSToolbarItem.Identifier.flexibleSpace) {
			toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
		}
		
		return toolbarItem
	}
	
	func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		return [DateToolbarItemID, SpinnerToolbarItemID, NSToolbarItem.Identifier.flexibleSpace, BalanceToolbarItemID, NSToolbarItem.Identifier.flexibleSpace, SearchToolbarItemID, AddToolbarItemID]
	}
	
	func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		return [NSToolbarItem.Identifier.flexibleSpace, SearchToolbarItemID, SpinnerToolbarItemID, DateToolbarItemID, AddToolbarItemID, BalanceToolbarItemID]
	}
	
	func windowDidBecomeMain(_ notification: Notification) {
		// Check for valid user credentials
		if Gateway.shared.isLoggedIn == false {
			// Present modal sheet
			let loginWindowController = LoginWindowController(windowNibName: NSNib.Name("LoginWindowController"))
			window?.beginSheet(loginWindowController.window!, completionHandler: { responseCode in
				if responseCode == .stop {
					// User pressed OK. Submit credentials. Dismiss sheet if successful.
					// Store form values in defaults
					let u = loginWindowController.usernameTextField.stringValue.trimmingCharacters(in: CharacterSet.whitespaces)
					let p = loginWindowController.passwordTextField.stringValue.trimmingCharacters(in: CharacterSet.whitespaces)
					Gateway.setStoredCredentials(u, password: p)

					// Send off the request to the Gateway to log in
					Gateway.shared.login()
					self.isTokenRequestInProgress = true
				} // Quit is .abort
				loginWindowController.window?.close()
			})
		}
	}
	
	@objc func loginNotificationReceived(_ notification: Notification) {
		// Ignore unless the login form is showing: it's a refetch of the token.
		isTokenRequestInProgress = false
		dateChangeNotificationReceived(notification)
	}
	
	@objc func logoutNotificationReceived(_ notification: Notification) {
		updateBalanceView(with: nil)
	}

	@objc func dateChangeNotificationReceived(_ note: Notification) {
		datePicker.dateValue = currentDate
		DispatchQueue.main.async {
			self.window?.title = "Fantastic Fiduciary Friend - " + self.titleDateFormatter.string(from: self.app.currentDate)
		}
		Gateway.shared.getBalanceSummary(forYear: app.currentDateComponents.year,
										 month: app.currentDateComponents.month)
		{ [weak self] message in
			if let balance = message.balanceSummary {
				DispatchQueue.main.async {
					self?.updateBalanceView(with: balance)
				}
			}
		}
	}
	
	@objc func dataUpdated(_ notification: Notification) {
		Gateway.shared.getBalanceSummary(forYear: app.currentDateComponents.year,
										 month: app.currentDateComponents.month)
		{ [weak self] message in
			DispatchQueue.main.async {
				self?.updateBalanceView(with: message.balanceSummary)
			}
		}
	}
	
	private func updateBalanceView(with balanceSummary: BalanceSummary?) {
		if let bs = balanceSummary {
			let month = app.currentDateComponents.month
			let balanceForCurrentMonth = bs.monthBalances[month]!
			monthBalance.income = balanceForCurrentMonth.income.floatValue
			monthBalance.expense = balanceForCurrentMonth.expense.floatValue
		}
		else {
			monthBalance.income = 0.0
			monthBalance.expense = 0.0
		}
	}

	@objc func transactionEditRequest(_ note: NSNotification) {
		if let info = note.userInfo as? Dictionary<String, Transaction> {
			let transaction = info.first?.value
			showEditForm(for: transaction)
		}
	}
	
	private func showEditForm(for transaction:Transaction?) {
		// Present modal sheet
		let editWindowController = EditTransactionWindowController(windowNibName: NSNib.Name("EditTransactionWindowController"))
		editWindowController.transaction = transaction
		window?.beginSheet(editWindowController.window!, completionHandler: { responseCode in
			if responseCode == .stop {
				// User pressed OK or Delete. Submit update/insert/delete.
				if let t = editWindowController.transaction {
					switch editWindowController.result {
					case .Create:
						Gateway.shared.createTransaction(transaction: t, callback: self.editCallback)
					case .Update:
						Gateway.shared.updateTransaction(transaction: t, callback: self.editCallback)
					case .Delete:
						Gateway.shared.deleteTransaction(transaction: t, callback: self.editCallback)
					}
				}
			} // Cancel is .abort
			
			editWindowController.window?.close()
		})
	}
	
	private func editCallback(message: Message) {
		if message.isError {
			print(message)
		}
		else {
			NotificationCenter.default.post(name: NSNotification.Name(Notifications.DataUpdated.rawValue), object: nil)
		}
	}

	private var transactionListViewController: TransListViewController? {
		for vc in tabViewController!.childViewControllers {
			if let tlvc = vc as? TransListViewController {
				return tlvc
			}
		}
		return nil
	}
	func searchFieldDidStartSearching(_ sender: NSSearchField) {
		tabViewController?.selectedTabViewItemIndex = 1 // Transaction list
		transactionListViewController?.searchString = sender.stringValue
	}
	
	func searchFieldDidEndSearching(_ sender: NSSearchField) {
		transactionListViewController?.searchString = nil
	}
	
	@IBAction func changeDate(_ sender: NSDatePicker) {
		currentDate = datePicker.dateValue
	}
	
	@IBAction func addTransaction(_ sender: NSButton) {
		showEditForm(for: nil)
	}
	
	@IBAction func todayMenuItemSelected(_ sender: Any) {
		app.currentDate = Date()
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
