//
//  EditTransactionWindowController.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-06-08.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa

class EditTransactionWindowController: NSWindowController {
	
	func setTransaction(_ t:Transaction?) {
		self.transaction = t
		// Only want to fetch series when called externally.
		fetchSeries()
	}
	
	private(set) var transaction:Transaction? {
		didSet {
			if transaction == nil {
				transaction = Transaction()
				transaction!.date = (NSApplication.shared.delegate as! AppDelegate).currentDate
			}
			updateUI()
		}
	}
	
	var seriesTransactions = [Transaction]() {
		didSet {
			DispatchQueue.main.async {
				self.seriesTableView.reloadData()
			}
		}
	}
	var deletedTransactions = [Transaction]()

	@IBOutlet weak var expenseCheckbox: NSButton!
	@IBOutlet weak var datePicker: NSDatePicker!
	@IBOutlet weak var transactionTypePopUp: NSPopUpButton!
	@IBOutlet weak var amountTextField: NSTextField!
	@IBOutlet weak var descriptionTextField: NSTextField!
	@IBOutlet weak var deleteButton: NSButton!
	@IBOutlet weak var cancelButton: NSButton!
	@IBOutlet weak var okButton: NSButton!
	
	@IBAction func disclosureClick(_ sender: NSButton) {
		if sender.state == .on {
			transactionSeriesStackView.isHidden = false
			resizeWindow(size: WindowSize.large)
		}
		else if sender.state == .off {
			resizeWindow(size: WindowSize.small)
			transactionSeriesStackView.isHidden = true
		}
	}
	@IBOutlet weak var disclosureTriangle: NSButton!
	@IBOutlet weak var transactionSeriesStackView: NSStackView!
	@IBOutlet weak var repeatPopup: NSPopUpButton!
	@IBOutlet weak var untilPopup: NSPopUpButton!
	@IBOutlet weak var seriesTableView: NSTableView!
	
	private struct WindowSize {
		static let small = CGSize(width: 480, height: 206)
		static let large = CGSize(width: 480, height: 500)
	}
	
	private func resizeWindow(size: CGSize) {
		if let w = self.window {
			let rect = NSRect(origin: w.frame.origin, size: size)
			w.setFrame(rect, display: true, animate: true)
		}
	}
	
	
	
	override func windowDidLoad() {
        super.windowDidLoad()
		seriesTableView.delegate = self
		seriesTableView.dataSource = self
		transactionSeriesStackView.isHidden = true
		updateUI()
		initSeriesRepeatPopupList()
		initSeriesRepeatUntilPopupList()
		resizeWindow(size: WindowSize.small)
    }
	
	private func fetchSeries() {
		if let t = transaction {
			if t.seriesID != nil {
				
				CachingGateway.shared.getTransactionSeries(withID: t.seriesID!) { [weak self] message in
					if var series = message.transactions {
						// We only want the parts of the series in the future
						series = series.filter { $0.date > t.date }
						series.sort {
							return $0.date < $1.date
						}
						self?.seriesTransactions = series
						if series.count > 0 {
							DispatchQueue.main.async {
								// It would be nice to "figure out" what the repeat is. For now, "unspecified"
								self?.repeatPopup.selectItem(at: RepeatPopupIndex.unspecified.rawValue)
								self?.untilPopup.selectItem(at: RepeatUntilPopupIndex.noEnd.rawValue)
								// Disclose the series
								self?.disclosureTriangle.state = .on
								self?.disclosureClick(self!.disclosureTriangle)
							}
						}
					}
				}
				
			}
		}
	}
	
	private func replaceSeries() {
		self.deletedTransactions.append(contentsOf: self.seriesTransactions)
		self.seriesTransactions.removeAll()
		self.seriesTransactions.append(contentsOf: self.generateSeries())
		if self.seriesTransactions.count == 0 {
			if var t = transaction {
				t.seriesID = nil
				t.modificationStatus = .dirty
				transaction = t
				updateUI()
			}
		}
	}
	
	private func generateSeries() -> [Transaction] {
		var series = [Transaction]()
		if isRepeatWellDefined == false {
			return series
		}
		
		if var t = transaction {
			let repeatType = RepeatPopupIndex(rawValue: repeatPopup.indexOfSelectedItem)!
			let endDate = self.repeatEndDate(for: t.date)
			let seriesDates = self.repeatDates(for: t.date, withFrequency: repeatType, endingOn: endDate)
			var seriesID = Transaction.createSeriesID()
			if t.seriesID != nil {
				seriesID = t.seriesID!
			}
			t.seriesID = seriesID
			for seriesDate in seriesDates {
				var seriesT = t 			// Copy on write means
				seriesT.date = seriesDate	// we will have a clone
				seriesT.id = 0
				seriesT.isNew = true
				seriesT.seriesID = seriesID
				series.append(seriesT)
			}
			transaction = t // Because we modified it. Copy on write.
		}
		
		return series
	}
	
	private func updateUI() {
		if okButton != nil {
			if let t = transaction {
				if t.transactionType == nil || t.transactionType!.isExpense {
					expenseCheckbox.state = .on
				}
				else {
					expenseCheckbox.state = .off
				}
				datePicker.dateValue = t.date
				amountTextField.stringValue = String(t.amount)
				descriptionTextField.stringValue = t.description ?? ""
				
				seriesTableView.reloadData()
				
				deleteButton.isEnabled = (t.isNew == false)
				okButton.isEnabled = isOKEnabled
			}
			initTranactionTypePopupList()
		}
	}
	
	private var isOKEnabled: Bool {
		if transaction?.modificationStatus == .dirty || deletedTransactions.count > 0 {
			return true
		}
		for t in seriesTransactions {
			if t.modificationStatus == .dirty || t.isNew {
				return true
			}
		}
		return false
	}
	
	private func initTranactionTypePopupList() {
		var types = TransactionType.transactionTypesForIncome()
		if let t = transaction {
			if t.transactionType == nil || t.transactionType!.isExpense  {
				types = TransactionType.transactionTypesForExpense()
			}
		}
		else {
			types = TransactionType.transactionTypesForExpense()
		}
		transactionTypePopUp.removeAllItems()
		for transactionType in types {
			transactionTypePopUp.addItem(withTitle: transactionType.emoji + " " + transactionType.description)
			let item = transactionTypePopUp.lastItem!
			item.tag = transactionType.code
			//item.image = transactionType.icon  // Too big!
			if let t = transaction, let tt = t.transactionType {
				if tt.code == transactionType.code {
					transactionTypePopUp.select(item)
				}
			}
		}
	}
	
	private enum RepeatPopupIndex: Int {
		case noRepeat = 0
		case unspecified = 1
		case daily = 2
		case weekly = 3
		case biweekly = 4
		case monthly = 5
	}
	private func initSeriesRepeatPopupList() {
		// Currently configured in IB
	}
	
	private enum RepeatUntilPopupIndex: Int {
		case noEnd = 0
		case month = 1
		case threeMonths = 2
		case sixMonths = 3
		case yearEnd = 4
	}
	private func initSeriesRepeatUntilPopupList() {
		// Currently configured in IB
	}

	// MARK: User interactions
	@IBAction func expenseCheckboxChanged(_ sender: NSButton) {
		let isExpense = sender.state == .on
		var defaultTT: TransactionType!
		if isExpense {
			defaultTT = TransactionType.transactionTypesForExpense().first
		}
		else {
			defaultTT = TransactionType.transactionTypesForIncome().first
		}
		
		transaction?.transactionType = defaultTT
		transaction?.modificationStatus = .dirty
		
		var alteredSeries = [Transaction]()
		for var seriesT in seriesTransactions {
			seriesT.transactionType = defaultTT
			seriesT.modificationStatus = .dirty
			alteredSeries.append(seriesT)
		}
		seriesTransactions = alteredSeries
		
		updateUI()
	}
	
	@IBAction func transactionDateChanged(_ sender: NSDatePicker) {
		transaction?.date = datePicker.dateValue
		
		if isRepeatWellDefined {
			// Remove old series and apply new.
			replaceSeries()
		}
		updateUI()
	}
	
	@IBAction func transactionTypeSelected(_ sender: NSPopUpButton) {
		let tt = TransactionType.transactionType(forCode: sender.selectedItem?.tag ?? 0)
		transaction?.transactionType = tt
		transaction?.modificationStatus = .dirty
		
		var alteredSeries = [Transaction]()
		for var seriesT in seriesTransactions {
			seriesT.transactionType = tt
			seriesT.modificationStatus = .dirty
			alteredSeries.append(seriesT)
		}
		seriesTransactions = alteredSeries

		updateUI()
	}
	@IBAction func amountChanged(_ sender: NSTextField) {
		let amt = sender.floatValue
		transaction?.amount = amt
		transaction?.modificationStatus = .dirty
		
		var alteredSeries = [Transaction]()
		for var seriesT in seriesTransactions {
			seriesT.amount = amt
			seriesT.modificationStatus = .dirty
			alteredSeries.append(seriesT)
		}
		seriesTransactions = alteredSeries

		updateUI()
	}
	@IBAction func descriptionChanged(_ sender: NSTextField) {
		transaction?.description = sender.stringValue
		transaction?.modificationStatus = .dirty
		
		var alteredSeries = [Transaction]()
		for var seriesT in seriesTransactions {
			seriesT.description = sender.stringValue
			seriesT.modificationStatus = .dirty
			alteredSeries.append(seriesT)
		}
		seriesTransactions = alteredSeries
		
		updateUI()
	}
	
	@IBAction func repeatPatternSelected(_ sender: NSPopUpButton) {
		if isRepeatWellDefined {
			replaceSeries()
		}
		else if repeatPopup.indexOfSelectedItem == RepeatPopupIndex.noRepeat.rawValue {
			// Remove the series
			replaceSeries()
		}
		updateUI()
	}
	
	@IBAction func repeatUntilSelected(_ sender: NSPopUpButton) {
		if isRepeatWellDefined {
			replaceSeries()
		}
		updateUI()
	}
	
	private var isRepeatWellDefined: Bool {
		let repeatIndex = repeatPopup.indexOfSelectedItem
		let untilIndex = untilPopup.indexOfSelectedItem
		
		let knownPattern = repeatIndex != RepeatPopupIndex.noRepeat.rawValue && repeatIndex != RepeatPopupIndex.unspecified.rawValue
		return knownPattern && untilIndex != RepeatUntilPopupIndex.noEnd.rawValue
	}
	
	private func repeatEndDate(for date:Date) -> Date {
		var endDate:Date!
		let until = RepeatUntilPopupIndex(rawValue: untilPopup.indexOfSelectedItem)!
		switch until {
		case .noEnd:
			return date
		case .month:
			endDate = Calendar.current.date(byAdding: .month, value: 1, to: date)!
		case .threeMonths:
			endDate = Calendar.current.date(byAdding: .month, value: 3, to: date)!
		case .sixMonths:
			endDate = Calendar.current.date(byAdding: .month, value: 6, to: date)!
		case .yearEnd:
			let dateComponents = Calendar.current.dateComponents(AppDelegate.unitsYM, from: date)
			let monthsToFollowingJanuary = 13 - dateComponents.month! // e.g. 13 - (may05) = 8 -> May + 8 months = next Jan
			endDate = Calendar.current.date(byAdding: .month, value: monthsToFollowingJanuary, to: date)!
		}
		// Find the last day of the month by going to the first, then subtracting one day
		var components = Calendar.current.dateComponents(AppDelegate.unitsYMD, from: endDate)
		components.day = 1
		endDate = Calendar.current.date(from: components)!
		endDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate)
		return endDate
	}

	private func repeatDates(for date:Date, withFrequency freq: RepeatPopupIndex, endingOn endDate:Date) -> [Date] {
		var dates = [Date]()
		
		var component:Calendar.Component = .month
		var offset = 1
		
		switch freq {
		case .daily:
			component = .day
		case .weekly:
			component = .weekOfYear
		case .biweekly:
			component = .weekOfYear
			offset = 2
		case .monthly:
			component = .month
		default:
			return dates
		}
		
		var seriesDate = Calendar.current.date(byAdding: component, value: offset, to: date)!
		while seriesDate <= endDate {
			dates.append(seriesDate)
			seriesDate = Calendar.current.date(byAdding: component, value: offset, to: seriesDate)!
		}
		return dates
	}
	
	
	@IBAction func ok(_ sender: Any) {
		self.window?.makeFirstResponder(nil)
		if transaction?.transactionType == nil {
			transactionTypeSelected(self.transactionTypePopUp)
		}
		self.window?.sheetParent?.endSheet(self.window!)
	}
	
	var isDelete: Bool {
		if transaction != nil && deletedTransactions.count > 0 {
			if transaction! == deletedTransactions.first! {
				return true
			}
		}
		return false
	}
	@IBAction func delete(_ sender: Any) {
		// Will want to confirm if this involves a series
		if transaction != nil {
			deletedTransactions.insert(transaction!, at: 0)
		}
		deletedTransactions.append(contentsOf: seriesTransactions)
		self.window?.sheetParent?.endSheet(self.window!)
	}
	
	@IBAction func cancel(_ sender: Any) {
		self.window?.sheetParent?.endSheet(self.window!, returnCode: .abort)
	}
}

extension EditTransactionWindowController: NSTableViewDelegate {
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		var text: String = ""
		var cellIdentifier: String = ""
		
		if row >= seriesTransactions.count {
			return nil
		}

		let dateFormatter = DateFormatter()
		dateFormatter.dateStyle = .long
		dateFormatter.timeStyle = .none
		
		let currFormatter = NumberFormatter()
		currFormatter.numberStyle = .currency
		
		let t = seriesTransactions[row]
		
		if tableColumn == tableView.tableColumns[0] {
			text = dateFormatter.string(from: t.date)
			cellIdentifier = "SeriesDateCell"
		}
		else if tableColumn == tableView.tableColumns[1] {
			text = currFormatter.string(from: NSNumber(value: t.amount))! + " " + (t.description ?? "")
			cellIdentifier = "SeriesTextCell"
		}

		let id = NSUserInterfaceItemIdentifier(cellIdentifier)
		
		if let cell = tableView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView {
			cell.textField?.stringValue = text
			return cell
		}
		return nil
	}

	func tableViewSelectionDidChange(_ notification: Notification) {
		// TODO
	}
}

extension EditTransactionWindowController: NSTableViewDataSource {
	func numberOfRows(in tableView: NSTableView) -> Int {
		return seriesTransactions.count
	}
}
