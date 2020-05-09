//
//  EditTransactionWindowController.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-06-08.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa

protocol TransactionSeriesEditor {
	var transactionSeries:TransactionSeries! { get }
	func setTransactionSeries(_ series:TransactionSeries)
}

class EditTransactionWindowController: NSWindowController, NSTextFieldDelegate, TransactionSeriesEditor {
	
	func setTransactionSeries(_ series:TransactionSeries) {
		self.transactionSeries = series
		if transactionSeries.needToLoadSeriesTransactions {
			transactionSeries.loadExistingSeriesTransactions { [weak self] success in
				DispatchQueue.main.async {
					self?.updateUI()
					self?.discloseSeries(self?.transactionSeries.isSeries ?? false ? .on : .off)
				}
			}
		}
		updateUI()
	}
	
	private(set) var transactionSeries:TransactionSeries! {
		didSet {
//			DispatchQueue.main.async {
//				self.updateUI()
//			}
		}
	}

	@IBOutlet weak var expenseCheckbox: NSButton!
	@IBOutlet weak var datePicker: NSDatePicker!
	@IBOutlet weak var transactionTypePopUp: NSPopUpButton!
	@IBOutlet weak var amountTextField: NSTextField!
	@IBOutlet weak var descriptionTextField: NSTextField!
	@IBOutlet weak var deleteButton: NSButton!
	@IBOutlet weak var cancelButton: NSButton!
	@IBOutlet weak var okButton: NSButton!
	@IBOutlet weak var disclosureButton: NSButton!
	
	@IBAction func disclosureClick(_ sender: NSButton) {
		discloseSeries(sender.state)
	}
	@IBOutlet weak var disclosureTriangle: NSButton!
	@IBOutlet weak var transactionSeriesStackView: NSStackView!
	@IBOutlet weak var repeatPopupStackView: NSStackView!
	@IBOutlet weak var repeatPopup: NSPopUpButton!
	@IBOutlet weak var untilPopupStackView: NSStackView!
	@IBOutlet weak var untilPopup: NSPopUpButton!
	@IBOutlet weak var seriesTableView: NSTableView!
	
	private func discloseSeries(_ disclosureState:NSControl.StateValue) {
		if disclosureButton.state != disclosureState {
			disclosureButton.state = disclosureState
		}
		if disclosureButton.state == .on {
			transactionSeriesStackView.isHidden = false
			repeatPopupStackView.isHidden = false
			untilPopupStackView.isHidden = false
			seriesTableView.isHidden = false
			resizeWindow(size: WindowSize.large)
		}
		else {
			repeatPopupStackView.isHidden = true
			untilPopupStackView.isHidden = true
			seriesTableView.isHidden = true
			transactionSeriesStackView.isHidden = true
			resizeWindow(size: WindowSize.small)
		}
	}
	
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
		disclosureButton.state = .off
		updateUI()
		initSeriesRepeatPopupList()
		initSeriesRepeatUntilPopupList()
		discloseSeries(.off)
		descriptionTextField.delegate = self
		//amountTextField.delegate = self
    }
	
	
	func controlTextDidChange(_ obj: Notification) {
		if transactionSeries != nil {
			transactionSeries!.description = descriptionTextField.stringValue
			if transactionSeries!.isSeries {
				seriesTableView.reloadData()
			}
		}
	}
	
	private func updateUI() {
		guard let _ = okButton else { return }
		if let ts = transactionSeries{
			if ts.transactionType.isExpense {
				expenseCheckbox.state = .on
			}
			else {
				expenseCheckbox.state = .off
			}
			datePicker.dateValue = ts.date
			amountTextField.stringValue = ts.amountString
			descriptionTextField.stringValue = ts.description
			
			let repeatInfo = ts.repeatInfo
			repeatPopup.selectItem(withTitle: repeatInfo.type.rawValue)
			untilPopup.selectItem(withTitle: repeatInfo.duration.rawValue)
			
			seriesTableView.reloadData()
			
			deleteButton.isEnabled = (ts.templateTransaction?.isNew == false)
			okButton.isEnabled = isOKEnabled
		}
		initTransactionTypePopupList()
	}
	
	private var isOKEnabled: Bool {
		if let ts = transactionSeries {
			return ts.isValid
		}
		return false
	}
	
	private func initTransactionTypePopupList() {
		var types = TransactionType.transactionTypesForIncome()
		if let ts = transactionSeries {
			if ts.transactionType.isExpense  {
				types = TransactionType.transactionTypesForExpense()
			}
		}
		else {
			types = TransactionType.transactionTypesForExpense()
		}
		transactionTypePopUp.removeAllItems()
		for transactionType in types {
			transactionTypePopUp.addItem(withTitle: transactionType.symbol + " " + transactionType.name)
			let item = transactionTypePopUp.lastItem!
			item.tag = transactionType.id
			//item.image = transactionType.icon  // Too big!
			if let ts = transactionSeries {
				if ts.transactionType.id == transactionType.id {
					transactionTypePopUp.select(item)
				}
			}
		}
	}

	private func initSeriesRepeatPopupList() {
		// Overwrite IB configuration with contents of enum
		repeatPopup.removeAllItems()
		for rt in RepeatType.allCases {
			repeatPopup.addItem(withTitle: rt.rawValue)
		}
		repeatPopup.selectItem(at: 0)
	}
	
	private func initSeriesRepeatUntilPopupList() {
		// Overwrite IB configuration with contents of enum
		untilPopup.removeAllItems()
		for rd in RepeatDuration.allCases {
			untilPopup.addItem(withTitle: rd.rawValue)
		}
		untilPopup.selectItem(at: 0)
	}

	// MARK: User interactions
	@IBAction func expenseCheckboxChanged(_ sender: NSButton) {
		let isExpense = sender.state == .on
		var defaultTT: TransactionType!
		if isExpense {
			defaultTT = TransactionType.defaultExpense
		}
		else {
			defaultTT = TransactionType.defaultIncome
		}
		
		transactionSeries?.transactionType = defaultTT
		updateUI()
	}
	
	@IBAction func transactionDateChanged(_ sender: NSDatePicker) {
		transactionSeries?.date = datePicker.dateValue
		if transactionSeries.isSeries {
			transactionSeries.generateTransactionsInSeries()
		}
		updateUI()
	}
	
	@IBAction func transactionTypeSelected(_ sender: NSPopUpButton) {
		let tt = TransactionType.transactionType(forCode: sender.selectedItem?.tag ?? 0) ??
			(self.expenseCheckbox.state == .on ? TransactionType.defaultExpense : TransactionType.defaultIncome)
		transactionSeries?.transactionType = tt
		updateUI()
	}
	
	@IBAction func amountChanged(_ sender: NSTextField) {
		transactionSeries?.amountString = sender.stringValue.replacingOccurrences(of: "$", with: "")
		updateUI()
	}
	
	@IBAction func descriptionChanged(_ sender: NSTextField) {
		transactionSeries?.description = sender.stringValue
		updateUI()
	}
	
	@IBAction func repeatPatternSelected(_ sender: NSPopUpButton) {
		if repeatPopup.indexOfSelectedItem == 0 {
			untilPopup.selectItem(at: 0)
		}
		setTransactionSeriesRepeatInfo()
		updateUI()
	}
	
	@IBAction func repeatUntilSelected(_ sender: NSPopUpButton) {
		setTransactionSeriesRepeatInfo()
		updateUI()
	}
	
	private func setTransactionSeriesRepeatInfo() {
		let selectedRepeatTypeIndex = repeatPopup.indexOfSelectedItem
		let rt = RepeatType(rawValue: repeatPopup.itemTitle(at: selectedRepeatTypeIndex)) ?? RepeatType.No
		
		let selectedRepeatUntilIndex = untilPopup.indexOfSelectedItem
		let rd = RepeatDuration(rawValue: untilPopup.itemTitle(at: selectedRepeatUntilIndex)) ?? RepeatDuration.None
		
		transactionSeries.repeatInfo = RepeatInfo(type: rt, duration: rd)
		transactionSeries.generateTransactionsInSeries()
	}
	
	@IBAction func ok(_ sender: Any) {
		self.window?.makeFirstResponder(nil)
		self.window?.sheetParent?.endSheet(self.window!)
	}

	@IBAction func delete(_ sender: Any) {
		// Will want to confirm if this involves a series
		transactionSeries.prepareForDeletion()
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
		
		if row >= transactionSeries.transactions.count {
			return nil
		}

		let dateFormatter = DateFormatter()
		dateFormatter.dateStyle = .long
		dateFormatter.timeStyle = .none
		
		let currFormatter = NumberFormatter()
		currFormatter.numberStyle = .currency
		
		let t = transactionSeries.transactions[row]
		
		if tableColumn == tableView.tableColumns[0] {
			text = t.isLocked ? FFFTransaction.lockedSymbol : t.transactionType.symbol
			cellIdentifier = "SeriesSymbolCell"
		}
		else if tableColumn == tableView.tableColumns[1] {
			text = dateFormatter.string(from: t.date)
			cellIdentifier = "SeriesDateCell"
		}
		else if tableColumn == tableView.tableColumns[2] {
			text = currFormatter.string(from: NSNumber(value: t.amount))! + " " + (t.description)
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
		return transactionSeries.transactions.count
	}
}
