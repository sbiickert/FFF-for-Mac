//
//  CheckerViewController.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-06-15.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa
import Combine

class CheckerViewController: FFFViewController {

	@IBOutlet weak var dragAndDropLabel: NSTextField!
	@IBOutlet weak var outlineView: NSOutlineView!
	@IBOutlet weak var outlineScrollView: NSScrollView!
	@IBOutlet weak var progressSpinner: NSProgressIndicator!
	
	@IBOutlet weak var alignButton: NSButton!
	@IBOutlet weak var createButton: NSButton!
	@IBOutlet weak var doneButton: NSButton!
	
	private var storage = Set<AnyCancellable>()
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
	private(set) var transactions = [FFFTransaction]()
	private(set) var matches = [TransactionMatch]() {
		didSet {
			outlineView.reloadData()
		}
	}
	
	@objc func doubleAction(_ outlineView:NSOutlineView) {
		let item = outlineView.item(atRow: outlineView.clickedRow)
		if (item as? MatchScore) != nil {
			alignTransaction(self)
		}
		if (item as? TransactionMatch) != nil {
			// Expand/collapse
			if outlineView.isItemExpanded(item) == false {
				outlineView.expandItem(item)
			}
			else {
				outlineView.collapseItem(item)
			}
		}
	}

	@IBAction func alignTransaction(_ sender: Any) {
		// Take selected item (MatchScore) and apply the date and amount of the bank transaction to the transaction
		let item = outlineView.item(atRow: outlineView.selectedRow)
		if let ms = item as? MatchScore {
			var t = ms.transaction
			if let tm = outlineView.parent(forItem: item) as? TransactionMatch {
				let bt = tm.bankTransaction
				t.amount = abs(bt.amount)
				t.date = bt.date
				// Puts the corrected transaction into our list
				self.transactions = self.transactions.filter { $0.id != t.id }
				self.transactions.append(t)
				// Updates the transaction in the database
				// Does not trigger dataRefreshed
				app.state.updateTransactions([t])
				// Redo the check
				self.check()
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
			var t = FFFTransaction()
			let isExpense = bt!.amount < 0
			t.amount = abs(bt!.amount)
			if isExpense {
				t.transactionType = TransactionType.defaultExpense
			}
			else {
				t.transactionType = TransactionType.defaultIncome
			}
			t.date = bt!.date
			t.description = bt!.description
			NotificationCenter.default.post(name: .showEditForm,
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
		outlineView.doubleAction = #selector(doubleAction(_:))
		
		if let cdv = view as? CheckerDragView {
			cdv.delegate = self
		}
		
		NotificationCenter.default.publisher(for: .openBankFile)
			.compactMap { $0.userInfo?["filename"] as? String }
			.sink { filename in
				self.openBankFile(filename: filename)
			}.store(in: &self.storage)
		
		// Sent by app.state
		NotificationCenter.default.publisher(for: .transactionsCreated)
			.compactMap { $0.userInfo?["t"] as? [FFFTransaction]}
			.sink { tList in
				self.transactions.append(contentsOf: tList)
				self.check()
			}.store(in: &self.storage)
    }
	
	private func openBankFile(filename: String) {
		let url = URL(fileURLWithPath: filename)
		tabViewController?.selectedTabViewItemIndex = 3  // Show this
		self.openCSV(url)
	}
	
	private func loadTransactionsForBankTransactions() {
		progressSpinner.doubleValue = 0.0
		progressSpinner.isHidden = false
		
		// Clear old data
		self.transactions.removeAll()
		self.matches = [TransactionMatch]()
		
		// Need to get all FFF transactions covering bank records
		if bankTransactions.count > 0 {
			var fromDate: Date? = nil
			var toDate: Date? = nil
			for bt in bankTransactions {
				if fromDate == nil || bt.date < fromDate! {
					fromDate = bt.date
				}
				if toDate == nil || bt.date > toDate! {
					toDate = bt.date
				}
			}
			
			let req = RestGateway.shared.createRequestGetSearchResults("", from: fromDate!, to: toDate!)
			progressSpinner.doubleValue = 10
			URLSession.shared.dataTaskPublisher(for: req)
				.tryMap { output in
					guard let response = output.response as? HTTPURLResponse, response.statusCode == 200 else {
						return Data()
					}
					return output.data
				}
				.decode(type: [CodableTransaction].self, decoder: JSONDecoder())
				.replaceError(with: [CodableTransaction]())
				.map { ctArray in
					ctArray.map { $0.transaction }
				}
				.sink { tArray in
					self.transactions = tArray
					self.check()
					// check() will continue updating the spinner and hide it
				}.store(in: &self.storage)
		}
	}
	
	override func dataRefreshed(_ notification: Notification) {
		DispatchQueue.main.async {
			self.loadTransactionsForBankTransactions()
		}
	}
	
	private func check() {
		var mList = [TransactionMatch]()
		
		// Whether this is called from loadTransactionsForBankTransactions
		// or from align or create
		DispatchQueue.main.async {
			self.progressSpinner.isHidden = false
			self.progressSpinner.doubleValue = 50
		}

		for bt in bankTransactions {
			let tm = self.checkTransaction(bt: bt)
			mList.append(tm)
		}
		DispatchQueue.main.async { self.progressSpinner.doubleValue = 70 }
		
		// At this point, all TransactionMatches in mList are .none or .partial
		mList.forEach { $0.sortPossibles() }
		mList.sort { $0.score > $1.score }
		
		for tm in mList {
			for possible in tm.possibleMatches {
				if possible.isCloseEnough {
					tm.matchedTransaction = possible.transaction
					tm.possibleMatches.removeAll()
					// Since this matched, it can't be a match for others
					for otherTM in mList {
						otherTM.removeFromPossibles(tm.matchedTransaction!)
					}
					break
				}
			}
		}
		DispatchQueue.main.async { self.progressSpinner.doubleValue = 80 }

		// Now that we've made the job as small as possible, apply fuzzy string to description
		for (i, tm) in mList.enumerated() {
			if tm.matchType == .partial {
				for (j, score) in tm.possibleMatches.enumerated() {
					let fuzz = fuzzyScore(find: score.transaction.description, in: tm.bankTransaction.description)
					mList[i].possibleMatches[j].descScore = fuzz
				}
				mList[i].possibleMatches.sort { $0.totalScore > $1.totalScore }
			}
		}
		DispatchQueue.main.async { self.progressSpinner.doubleValue = 90 }

		// Sort by status
		mList.sort {lhs, rhs in
			// .none < .partial < .complete
			return lhs.matchType.rawValue < rhs.matchType.rawValue
		}
		
		// Set matches, will update outlineview
		DispatchQueue.main.async { [weak self] in
			self?.progressSpinner.doubleValue = 100
			self?.progressSpinner.isHidden = true
			self?.matches = mList
		}
	}
	
	private func checkTransaction(bt: BankTransaction) -> TransactionMatch {
		let tMatch = TransactionMatch(with: bt)
		
		for t in self.transactions {
			var dateDiff = calcDateDiff(date1: t.date, date2: bt.date)
			let amtDiff = abs(t.amount - abs(bt.amount)) //t.amount is always positive
			
			// Amount score. Perfect is 1.0, approaches zero
			var amtScore:Float = 0.0
			if amtDiff < t.amount {
				let pctAmtDiff = (t.amount - amtDiff) / t.amount
				amtScore = pctAmtDiff * pctAmtDiff
			}
			
			// Date score. Perfect is 1.0. Zero at 14 days.
			var dateScore:Float = 0.0
			dateDiff = min(dateDiff, 14)
			let dateDiffValue = Float(14 - dateDiff) / 14.0
			dateScore = dateDiffValue * dateDiffValue
			
			let matchScore = MatchScore(amountScore: amtScore, dateScore: dateScore, descScore: 0.0, transaction: t)
			
			if matchScore.dateScore == 0 || matchScore.amountScore < 0.5 || matchScore.totalScore < 1.0 {
				// skip
			}
			else {
				// Description Score (1.0 for perfect, fuzzy logic)
				// This step is slow, so commenting it out. Will apply desc string to the sorting of .partials
				// matchScore.descScore = fuzzyScore(find: t.description, in: bt.description)
				tMatch.possibleMatches.append(matchScore)
			}
		}
		return tMatch
	}
	
//	private var savedDateDiffs = Dictionary<String, Int>()
	private func calcDateDiff(date1:Date, date2: Date) -> Int {
//		let dates = [date1, date2].sorted()
//		let key = "\(dates)"
//		if let diff = savedDateDiffs[key] {
//			return diff
//		}
		let diff = abs(Calendar.current.dateComponents([.day], from: date1, to: date2).day!)
//		savedDateDiffs[key] = diff
		return diff
	}
	
//	private var fuse = Fuse()
	private func fuzzyScore(find str1: String, in str2: String) -> Float {
		// FuzzyWuzzy: same as used in python, but slower
		let fuzzScore = String.fuzzTokenSetRatio(str1: str1, str2: str2) // 0 to 100
		return Float(fuzzScore) / 100.0
		// Fuse: faster, but not fast enough
//		if let result = fuse.search(t.description.uppercased(), in: bt.description.uppercased()) {
//			matchScore.descScore = Float(result.score)
//		}
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
				return tm.matchedTransaction!
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
		
		var textColor = NSColor.controlTextColor

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
				if tm.bankTransaction.amount > 0 {
					textColor = NSColor(named: NSColor.Name("incomeTextColor")) ?? NSColor.purple
				}
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
		if let transaction = item as? FFFTransaction {
			if tableColumn == outlineView.tableColumns[0] {
				cellIdentifier = CellID.Date
				text = dateFormatter.string(from: transaction.date)
			}
			else if tableColumn == outlineView.tableColumns[1] {
				cellIdentifier = CellID.Amount
				text = currFormatter.string(from: NSNumber(value: transaction.amount))!
				if transaction.transactionType.isExpense == false {
					textColor = NSColor(named: NSColor.Name("incomeTextColor")) ?? NSColor.purple
				}
			}
			else if tableColumn == outlineView.tableColumns[2] {
				cellIdentifier = CellID.TransactionType
				let emoji = transaction.transactionType.symbol
				text = emoji + " " + (transaction.transactionType.name)
				if transaction.transactionType.isExpense == false {
					textColor = NSColor(named: NSColor.Name("incomeTextColor")) ?? NSColor.purple
				}
			}
			else if tableColumn == outlineView.tableColumns[3] {
				cellIdentifier = CellID.Description
				text = transaction.description
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
				if ms.transaction.transactionType.isExpense == false {
					textColor = NSColor(named: NSColor.Name("incomeTextColor")) ?? NSColor.purple
				}
			}
			else if tableColumn == outlineView.tableColumns[2] {
				cellIdentifier = CellID.TransactionType
				let emoji = ms.transaction.transactionType.symbol
				text = emoji + " " + (ms.transaction.transactionType.name)
				if ms.transaction.transactionType.isExpense == false {
					textColor = NSColor(named: NSColor.Name("incomeTextColor")) ?? NSColor.purple
				}
			}
			else if tableColumn == outlineView.tableColumns[3] {
				cellIdentifier = CellID.Description
				let pct = pctFormatter.string(from: NSNumber(value: ms.totalScore))
				text = "\(pct ?? ""):  \(ms.transaction.description)"
			}
		}
		let id = NSUserInterfaceItemIdentifier(cellIdentifier)
		
		view = outlineView.makeView(withIdentifier: id, owner: self) as? NSTableCellView
		if let textField = view?.textField {
			textField.stringValue = text
			textField.textColor = textColor
		}
		return view
	}
	
	func outlineViewSelectionDidChange(_ notification: Notification) {
		var isAlignEnabled = false
		var isCreateEnabled = false
		
		let item = outlineView.item(atRow: outlineView.selectedRow)
		
		// Determine if the selected item is a match score with < 100%
		if let _ = item as? MatchScore {
			isAlignEnabled = true
			isCreateEnabled = true
		}
		// Or if this is a TransactionMatch that is .partial or .none
		if let tm = item as? TransactionMatch {
			isCreateEnabled = tm.matchType != .complete
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
