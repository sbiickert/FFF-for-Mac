//
//  CheckerViewController.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-06-15.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa

class CheckerViewController: FFFViewController {

	@IBOutlet weak var dragAndDropLabel: NSTextField!
	@IBOutlet weak var outlineView: NSOutlineView!
	@IBOutlet weak var outlineScrollView: NSScrollView!
	
	@IBOutlet weak var alignButton: NSButton!
	@IBOutlet weak var createButton: NSButton!
	@IBOutlet weak var doneButton: NSButton!
		
	var bankTransactions = [BankTransaction]() {
		didSet {
			transactions.removeAll()
			matches = [TransactionMatch]()
			
			// Sort by date
			bankTransactions.sort {lhs, rhs in
				return lhs.date < rhs.date
			}
			
			self.loadTransactionsForBankTransactions()
			outlineScrollView.isHidden = (bankTransactions.count == 0)
		}
	}
	private(set) var transactions = [Transaction]()
	private(set) var matches = [TransactionMatch]() {
		didSet {
			outlineView.reloadData()
		}
	}

	@IBAction func alignTransaction(_ sender: Any) {
		// Take selected item (MatchScore) and apply the date and amount of the bank transaction to the transaction
		let item = outlineView.item(atRow: outlineView.selectedRow)
		if let ms = item as? MatchScore {
			var t = ms.transaction
			if let tm = outlineView.parent(forItem: item) as? TransactionMatch {
				let bt = tm.bankTransaction!
				t.amount = abs(bt.amount)
				t.date = bt.date
				CachingGateway.shared.updateTransaction(transaction: t) {  message in  //[weak self]
					// Replace the transaction in the stored list and refresh check
					// At the moment, this is redundant because any data update refreshes the whole list
//					if let seq = self?.transactions.enumerated() {
//						for (index, storedTransaction) in seq {
//							if t.id == storedTransaction.id {
//								self?.transactions.remove(at: index)
//								self?.transactions.append(t)
//								self?.check()
//								break
//							}
//						}
//					}
				}
			}
		}
	}
	
	@IBAction func createTransaction(_ sender: Any) {
		let item = outlineView.item(atRow: outlineView.selectedRow)
		
		var bt: BankTransaction?
		if let tm = item as? TransactionMatch {
			bt = tm.bankTransaction
		}
		else if let _ = item as? MatchScore {
			if let tm = outlineView.parent(forItem: item) as? TransactionMatch {
				bt = tm.bankTransaction
			}
		}

		if bt != nil {
			var t = Transaction()
			let isExpense = bt!.amount < 0
			t.amount = abs(bt!.amount)
			if isExpense {
				t.transactionType = TransactionType.transactionTypesForExpense().first
			}
			else {
				t.transactionType = TransactionType.transactionTypesForIncome().first
			}
			t.date = bt!.date
			t.description = bt!.description
			NotificationCenter.default.post(name: NSNotification.Name(Notifications.ShowEditForm.rawValue),
											object: self,
											userInfo: ["t": t])
		}
	}
	
	@IBAction func done(_ sender: Any) {
		self.bankTransactions = [BankTransaction]()
	}
	
	override func viewDidLoad() {
        super.viewDidLoad()
		
		outlineView.delegate = self
		outlineView.dataSource = self
		
		if let cdv = view as? CheckerDragView {
			cdv.delegate = self
		}
		NotificationCenter.default.addObserver(self,
											   selector: #selector(openBankFileNotificationReceived(_:)),
											   name: NSNotification.Name(rawValue: Notifications.OpenBankFile.rawValue),
											   object: nil)
    }
	
	@objc func openBankFileNotificationReceived(_ notification: Notification) {
		// userinfo has the name of the file at key "filename"
		if let userInfo = notification.userInfo, let filename = userInfo["filename"] as? String {
			let url = URL(fileURLWithPath: filename)
			tabViewController?.selectedTabViewItemIndex = 3  // Show this
			self.openCSV(url)
		}
	}
	
	private func loadTransactionsForBankTransactions() {
		// Clear old data
		self.transactions.removeAll()
		self.matches = [TransactionMatch]()
		
		// Need to get all FFF transactions covering bank records
		if bankTransactions.count > 0 {
			var timeWindow = [(year:Int, month:Int)]()
			for bt in bankTransactions {
				let ym = getYM(from: bt.date)
				if timeWindow.count == 0 || timeWindow.last! != ym {
					timeWindow.append(ym)
				}
			}
			
			for ym in timeWindow {
				CachingGateway.shared.getTransactions(forYear: ym.year, month: ym.month) {message in
					if var received = message.transactions {
						received.append(contentsOf: self.transactions)
						self.transactions = received
						self.check()
					}
				}
			}
		}
	}
	
	override func dataUpdated(_ notification: Notification) {
		DispatchQueue.main.async {
			self.loadTransactionsForBankTransactions()
		}
	}
	
	private func check() {
		// Will be called multiple times if the timeWindow spans multiple months
		var mList = [TransactionMatch]()
		
		var transactionsWorkingList = transactions
		
		for bt in bankTransactions {
			let tm = TransactionMatch(with: bt)
			for (index, t) in transactionsWorkingList.enumerated() {
				tm.addTransaction(t)  // Will only be appended if score > 0.0
				if tm.matchType == .complete {
					// Don't need to evaluate this transaction any more
					transactionsWorkingList.remove(at: index)
					// Can't be a possible for any other bank transaction
					for previousMatch in mList {
						previousMatch.removeFromPossibles(t)
					}
					break
				}
			}
			if tm.matchType != .none {
				mList.append(tm)
			}
		}
		// Sort by status
		mList.sort {lhs, rhs in
			return lhs.matchType.rawValue < rhs.matchType.rawValue
		}
		DispatchQueue.main.async { [weak self] in
			// Set matches, will update outlineview
			self?.matches = mList
		}
	}
	
	private func getYM(from date:Date) -> (year:Int, month:Int) {
		let components = Calendar.current.dateComponents(AppDelegate.unitsYMD, from: date)
		return (year: components.year!, month: components.month!)
	}
}

extension CheckerViewController: NSOutlineViewDataSource {
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		var n = 0
		if let tm = item as? TransactionMatch {
			if tm.matchType == .complete {
				n = 1
			}
			else {
				n = tm.possibleMatches.count
			}
		}
		else if item == nil {
			return matches.count
		}
		return n
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		if let tm = item as? TransactionMatch {
			if tm.matchType == .complete {
				return MatchScore(score: 1.0, transaction: tm.matchedTransaction!)
			}
			return tm.possibleMatches[index]
		}
		else {
			// This is a child of root (nil)
			return matches[index]
		}
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		return item is TransactionMatch
	}
}

extension CheckerViewController: NSOutlineViewDelegate {
	fileprivate struct CellID {
		static let Amount = "AmountCellID"
		static let TransactionType = "TransactionTypeCellID"
		static let Date = "DateCellID"
		static let Description = "DescriptionCellID"
	}

	func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
		var view: NSTableCellView?
		var text: String = ""
		var cellIdentifier: String = ""

		let dateFormatter = DateFormatter()
		dateFormatter.dateStyle = .long
		dateFormatter.timeStyle = .none

		let currFormatter = NumberFormatter()
		currFormatter.numberStyle = .currency

		let pctFormatter = NumberFormatter()
		pctFormatter.numberStyle = .percent

		if let tm = item as? TransactionMatch {
			if tableColumn == outlineView.tableColumns[0] {
				cellIdentifier = CellID.Date
				text = dateFormatter.string(from: tm.bankTransaction.date)
			}
			else if tableColumn == outlineView.tableColumns[1] {
				cellIdentifier = CellID.Amount
				text = currFormatter.string(from: NSNumber(value: tm.bankTransaction.amount))!
			}
			else if tableColumn == outlineView.tableColumns[2] {
				cellIdentifier = CellID.TransactionType
				text = MatchType.stringValue(tm.matchType)
			}
			else if tableColumn == outlineView.tableColumns[3] {
				cellIdentifier = CellID.Description
				text = tm.bankTransaction.description
			}
		}
		if let ms = item as? MatchScore {
			if tableColumn == outlineView.tableColumns[0] {
				cellIdentifier = CellID.Date
				text = dateFormatter.string(from: ms.transaction.date)
			}
			else if tableColumn == outlineView.tableColumns[1] {
				cellIdentifier = CellID.Amount
				text = currFormatter.string(from: NSNumber(value: ms.transaction.amount))!
			}
			else if tableColumn == outlineView.tableColumns[2] {
				cellIdentifier = CellID.TransactionType
				let emoji = ms.transaction.transactionType?.emoji ?? "💥"
				text = emoji + " " + (ms.transaction.transactionType?.description ?? "")
			}
			else if tableColumn == outlineView.tableColumns[3] {
				cellIdentifier = CellID.Description
				let pct = pctFormatter.string(from: NSNumber(value: ms.score))
				text = "\(pct ?? ""):  \(ms.transaction.description ?? "")"
			}
		}
		let id = NSUserInterfaceItemIdentifier(cellIdentifier)
		
		view = outlineView.makeView(withIdentifier: id, owner: self) as? NSTableCellView
		if let textField = view?.textField {
			textField.stringValue = text
		}
		return view
	}
	
	func outlineViewSelectionDidChange(_ notification: Notification) {
		var isAlignEnabled = false
		var isCreateEnabled = false
		
		let item = outlineView.item(atRow: outlineView.selectedRow)
		
		// Determine if the selected item is a match score with < 100%
		if let ms = item as? MatchScore {
			isAlignEnabled = ms.score < 1.0
			isCreateEnabled = ms.score < 1.0
		}
		// Or if this is a TransactionMatch that is .partial or .none
		if let tm = item as? TransactionMatch {
			isCreateEnabled = tm.matchType != .complete
			if outlineView.isItemExpanded(item) == false {
				outlineView.expandItem(item)
			}
		}
		
		alignButton.isEnabled = isAlignEnabled
		createButton.isEnabled = isCreateEnabled
	}
}

extension CheckerViewController: CheckerDragViewDelegate {
	@discardableResult
	func openCSV(_ url: URL) -> Bool {
		print("Will open CSV with url \(url)")
		var bankTransactions = [BankTransaction]()
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "MM/dd/yyyy"
		
		do {
			let csvString = try String(contentsOf: url)
			let csv = CSwiftV(with: csvString)
			for (index, row) in csv.keyedRows!.enumerated() {
				let bt = BankTransaction(id: index,
										 date: dateFormatter.date(from: row["Transaction Date"]!)!,
										 desc1: row["Description 1"]!,
										 desc2: row["Description 2"],
										 amount: Float(row["CAD$"]!)!)
				if bt.ignorable == false {
					bankTransactions.append(bt)
				}
			}
		}
		catch {
			print("Error opening CSV file: \(error)")
			return false
		}
		
		self.bankTransactions = bankTransactions
		return true
	}
}
