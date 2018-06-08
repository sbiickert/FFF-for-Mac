//
//  EditTransactionWindowController.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-06-08.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa

class EditTransactionWindowController: NSWindowController {

	enum Result {
		case Create
		case Update
		case Delete
	}
	
	var transaction:Transaction? {
		didSet {
			if transaction == nil {
				transaction = Transaction()
				transaction!.date = (NSApplication.shared.delegate as! AppDelegate).currentDate
				result = .Create
			}
			else if transaction!.isNew == false {
				result = .Update
			}
			updateUI()
		}
	}
	
	private(set) var result = EditTransactionWindowController.Result.Create
	
	@IBOutlet weak var expenseCheckbox: NSButton!
	@IBOutlet weak var datePicker: NSDatePicker!
	@IBOutlet weak var transactionTypePopUp: NSPopUpButton!
	@IBOutlet weak var amountTextField: NSTextField!
	@IBOutlet weak var descriptionTextField: NSTextField!
	@IBOutlet weak var deleteButton: NSButton!
	@IBOutlet weak var cancelButton: NSButton!
	@IBOutlet weak var okButton: NSButton!
	
	override func windowDidLoad() {
        super.windowDidLoad()
		updateUI()
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
				deleteButton.isEnabled = (t.isNew == false)
				okButton.isEnabled = (t.modificationStatus == .dirty)
			}
			initTranactionTypePopupList()
		}
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
	
	@IBAction func expenseCheckboxChanged(_ sender: NSButton) {
		let isExpense = sender.state == .on
		if isExpense {
			transaction?.transactionType = TransactionType.transactionTypesForExpense().first
		}
		else {
			transaction?.transactionType = TransactionType.transactionTypesForIncome().first
		}
		transaction?.modificationStatus = .dirty
		updateUI()
	}
	@IBAction func transactionDateChanged(_ sender: NSDatePicker) {
		transaction?.date = datePicker.dateValue
	}
	@IBAction func transactionTypeSelected(_ sender: NSPopUpButton) {
		let tt = TransactionType.transactionType(forCode: sender.selectedItem?.tag ?? 0)
		transaction?.transactionType = tt
		transaction?.modificationStatus = .dirty
		updateUI()
	}
	@IBAction func amountChanged(_ sender: NSTextField) {
		let amt = sender.floatValue
		transaction?.amount = amt
		transaction?.modificationStatus = .dirty
		updateUI()
	}
	@IBAction func descriptionChanged(_ sender: NSTextField) {
		transaction?.description = sender.stringValue
		transaction?.modificationStatus = .dirty
		updateUI()
	}
	
	
	@IBAction func ok(_ sender: Any) {
		self.window?.sheetParent?.endSheet(self.window!)
	}
	@IBAction func delete(_ sender: Any) {
		result = .Delete
		self.window?.sheetParent?.endSheet(self.window!)
	}
	@IBAction func cancel(_ sender: Any) {
		self.window?.sheetParent?.endSheet(self.window!, returnCode: .abort)
	}
}
