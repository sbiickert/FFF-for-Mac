//
//  MainWindowController.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-02-17.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa
import Combine

class MainWindowController: NSWindowController,
							NSWindowDelegate,
							NSToolbarDelegate,
							NSSearchFieldDelegate,
							LoginPresenterDelegate
{
	private let SearchToolbarItemID =  NSToolbarItem.Identifier(rawValue: "Search")
	//private let DateToolbarItemID =  NSToolbarItem.Identifier(rawValue: "Date")
	private let CustomDateToolbarItemID =  NSToolbarItem.Identifier(rawValue: "CustomDate")
	private let AddToolbarItemID =  NSToolbarItem.Identifier(rawValue: "Add")
	private let BalanceToolbarItemID =  NSToolbarItem.Identifier(rawValue: "Balance")

	@IBOutlet var searchField: NSSearchField!
	//@IBOutlet var customDatePicker: DateView!
	@IBOutlet var datePickerImproved: DateViewImproved!
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
	var storage = Set<AnyCancellable>()
	
    override func windowDidLoad() {
		
		// Automatic saving/restoring of window state
		shouldCascadeWindows = false
		window?.setFrameAutosaveName("FFF Main Window")
		
        super.windowDidLoad()

		NotificationCenter.default.addObserver(self,
											   selector: #selector(loginNotificationReceived(_:)),
											   name: .loginResponse,
											   object: nil)

		NotificationCenter.default.addObserver(self,
											   selector: #selector(logoutNotificationReceived(_:)),
											   name: .logoutResponse,
											   object: nil)

		NotificationCenter.default.addObserver(self,
											   selector: #selector(dateChangeNotificationReceived(_:)),
											   name: .currentMonthChanged,
											   object: nil)

		NotificationCenter.default.addObserver(self,
											   selector: #selector(transactionEditRequest(_:)),
											   name: .showEditForm,
											   object: nil)

		NotificationCenter.default.publisher(for: .stateChange_MonthlyBalance)
			.compactMap { $0.userInfo?["value"] as? BalanceSummary }
			.receive(on: DispatchQueue.main)
			.sink { bs in
				self.updateBalanceView(with: bs)
		}.store(in: &self.storage)

		titleDateFormatter.dateStyle = .long
		updateWindowTitle()
		
		tabViewController = window?.contentViewController as? NSTabViewController
		app.state.loginDelegate = self
    }
	
	private func updateWindowTitle() {
		var title = "Fantastic Fiduciary Friend - " + titleDateFormatter.string(from: app.currentDate)
		if RestGateway.shared.isDebugging {
			title = "DEBUGGING " + title
		}
		window?.title = title
	}
	
	func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
		var isValid = true //super.validateMenuItem(menuItem)
		if menuItem == app.duplicateMenuItem {
			isValid = app.selectedTransaction != nil
		}
		if menuItem == app.deleteMenuItem {
			isValid = app.selectedTransaction != nil && app.selectedTransaction!.seriesID == nil
		}
		return isValid
	}

	func customToolbarItem(itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, label: String, paletteLabel: String, toolTip: String, target: AnyObject, itemContent: AnyObject, action: Selector?, minSize: NSSize?=nil) -> NSToolbarItem? {
		
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
		if let size = minSize {
			toolbarItem.minSize = size
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
//		else if (itemIdentifier == DateToolbarItemID) {
//			toolbarItem = customToolbarItem(itemForItemIdentifier: DateToolbarItemID, label: "Current Date", paletteLabel: "Current Date", toolTip: "Change the current date", target: self, itemContent: self.datePicker, action: nil)!
//		}
		else if (itemIdentifier == CustomDateToolbarItemID) {
			toolbarItem = customToolbarItem(itemForItemIdentifier: CustomDateToolbarItemID, label: "Current Date", paletteLabel: "Current Date", toolTip: "Change the current date", target: self, itemContent: self.datePickerImproved, action: nil)!
		}
		else if (itemIdentifier == AddToolbarItemID) {
			toolbarItem = customToolbarItem(itemForItemIdentifier: AddToolbarItemID, label: "Add Transaction", paletteLabel: "Add", toolTip: "Create a new transaction", target: self, itemContent: self.addButton, action: nil, minSize: NSSize(width: 64, height: 64))!
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
		return [CustomDateToolbarItemID, NSToolbarItem.Identifier.flexibleSpace, BalanceToolbarItemID, NSToolbarItem.Identifier.flexibleSpace, SearchToolbarItemID, AddToolbarItemID]
	}
	
	func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		return [NSToolbarItem.Identifier.flexibleSpace, SearchToolbarItemID, AddToolbarItemID, BalanceToolbarItemID, CustomDateToolbarItemID]
	}
	
	func windowDidBecomeMain(_ notification: Notification) {
		// Check for valid user credentials
		if RestGateway.shared.userName == "" {
			presentLoginSheet()
		}
	}
	
	func showLogin() {
		DispatchQueue.main.async {
			// Present modal sheet
			let loginWindowController = LoginWindowController(windowNibName: "LoginWindowController")
			self.window?.beginSheet(loginWindowController.window!, completionHandler: { responseCode in
				if responseCode == .stop {
					// User pressed OK. Submit credentials. Dismiss sheet if successful.
					// Store form values in defaults
					let u = loginWindowController.usernameTextField.stringValue.trimmingCharacters(in: CharacterSet.whitespaces)
					let p = loginWindowController.passwordTextField.stringValue.trimmingCharacters(in: CharacterSet.whitespaces)
					RestGateway.setStoredCredentials(u, password: p)
					// Send login notification
					NotificationCenter.default.post(name: .loginResponse,
													object: self)
				} // Quit is .abort
				loginWindowController.window?.close()
			})
		}
	}
	

	private func presentLoginSheet() {
		self.showLogin()
	}
	
	@objc func loginNotificationReceived(_ notification: Notification) {
		// Ignore unless the login form is showing: it's a refetch of the token.
		dateChangeNotificationReceived(notification)
	}
	
	@objc func logoutNotificationReceived(_ notification: Notification) {
		presentLoginSheet()
	}

	@objc func dateChangeNotificationReceived(_ note: Notification) {
		DispatchQueue.main.async {
			self.updateWindowTitle()
			self.datePickerImproved.date = self.app.currentDate
		}
	}
	
	private func updateBalanceView(with balanceSummary: BalanceSummary?) {
		if let bs = balanceSummary {
			let month = app.currentDateComponents.month
			if let balanceForCurrentMonth = bs.balance(forMonth: month) {
				monthBalance.income = Float(balanceForCurrentMonth.income)
				monthBalance.expense = Float(balanceForCurrentMonth.expense)
			}
		}
		else {
			monthBalance.income = 0.0
			monthBalance.expense = 0.0
		}
	}

	@objc func transactionEditRequest(_ note: NSNotification) {
		if let info = note.userInfo as? Dictionary<String, FFFTransaction> {
			let transaction = info.first?.value
			showEditForm(for: transaction)
		}
	}
	
	
	enum AddType {
		case normal
		case incomeExpensePair
	}
	
	private func showEditForm(for transaction:FFFTransaction?, _ addType: AddType = .normal) {
		// Nil transaction means a new transaction
		var editTransaction:FFFTransaction! = transaction
		if editTransaction == nil {
			editTransaction = FFFTransaction()
			editTransaction.date = app.currentDate
		}
		
		// All edits are done based on a series
		var series:TransactionSeries = NormalTransactionSeries()
		series.templateTransaction = editTransaction
		
		if transaction == nil && addType == .incomeExpensePair {
			series = IncomeExpenseTransactionSeries(templateTransaction: editTransaction)
		}
		
		func editWindowCallback(_ responseCode: NSApplication.ModalResponse) -> Void {
			if responseCode == .stop {
				/*
				User pressed OK or Delete. Submit update/insert/delete.
				*/
				if let tSeries = (editWindowController as? TransactionSeriesEditor)?.transactionSeries {
					print("Save transaction series to database")
					// Delete any (future) transactions that were redefined
					let delIDs = tSeries.garbage.map { $0.id }
					self.app.state.deleteTransactions(withIDs: delIDs)
					
					// Update any dirty transactions
					let dirtyTransactions = tSeries.transactions.filter {
						$0.modificationStatus == .dirty && $0.isNew == false
					}
					self.app.state.updateTransactions(dirtyTransactions)
					if let firstT = dirtyTransactions.first {
						self.app.saveRecentTransaction(firstT)
					}

					// Create any new transactions
					let newTransactions = tSeries.transactions.filter {
						$0.modificationStatus == .dirty && $0.isNew
					}
					self.app.state.createTransactions(newTransactions)
					if let firstT = newTransactions.first {
						self.app.saveRecentTransaction(firstT)
					}
				}
			} // Cancel is .abort
			
			editWindowController.window?.close()
		}
		
		// Present modal sheet
		let editWindowController = (addType == .normal) ?
			EditTransactionWindowController(windowNibName: "EditTransactionWindowController") :
			EditTransactionPairWindowController(windowNibName: "EditTransactionPairWindowController")
		if let tse = editWindowController as? TransactionSeriesEditor {
			tse.setTransactionSeries(series)
		}
		window?.beginSheet(editWindowController.window!, completionHandler: editWindowCallback)
	}
	

	private var transactionListViewController: TransListViewController? {
		for vc in tabViewController!.children {
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

	@IBAction func changeDateCustom(_ sender: DateViewImproved) {
		currentDate = datePickerImproved.date
	}
	
	@IBAction func addTransaction(_ sender: NSButton) {
		if NSEvent.modifierFlags.contains(.option) {
			showEditForm(for: nil, .incomeExpensePair)
		}
		else {
			showEditForm(for: nil)
		}
	}
	
	@IBAction func addIncomeExpense(_ sender: Any) {
		showEditForm(for: nil, .incomeExpensePair)
	}
	
	@IBAction func duplicateTransaction(_ sender: Any) {
		if var duplicateTransaction = app.selectedTransaction {
			// Copy on Write makes the clone
			duplicateTransaction.id = -1
			showEditForm(for: duplicateTransaction)
		}
	}
	
	@IBAction func deleteTransaction(_ sender: Any) {
		if let selected = app.selectedTransaction {
			app.state.deleteTransactions(withIDs: [selected.id])
		}
	}
	
	@IBAction func logoutMenuItemSelected(_ sender: Any) {
		RestGateway.forgetUser()
		NotificationCenter.default.post(name: .logoutResponse,
										object: self)
	}
	
	@IBAction func refreshMenuItemSelected(_ sender: Any) {
		NotificationCenter.default.post(name: .refreshData, object: nil)
	}
	
	@IBAction func todayMenuItemSelected(_ sender: Any) {
		app.currentDate = Date()
	}
	
	@IBAction func nextMonthMenuItemSelected(_ sender: Any) {
		app.currentDate = Calendar.current.date(byAdding: .month, value: 1, to: app.currentDate)!
	}
	
	@IBAction func prevMonthMenuItemSelected(_ sender: Any) {
		app.currentDate = Calendar.current.date(byAdding: .month, value: -1, to: app.currentDate)!
	}
	
	@IBAction func nextYearMenuItemSelected(_ sender: Any) {
		app.currentDate = Calendar.current.date(byAdding: .year, value: 1, to: app.currentDate)!
	}
	
	@IBAction func prevYearMenuItemSelected(_ sender: Any) {
		app.currentDate = Calendar.current.date(byAdding: .year, value: -1, to: app.currentDate)!
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
