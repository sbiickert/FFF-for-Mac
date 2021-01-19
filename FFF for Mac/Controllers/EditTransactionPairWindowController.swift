//
//  EditTransactionPairWindowController.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2020-04-30.
//  Copyright © 2020 ii Softwerks. All rights reserved.
//

import Cocoa

class EditTransactionPairWindowController: NSWindowController, NSTextFieldDelegate, TransactionSeriesEditor {
	
	private(set) var transactionSeries: TransactionSeries!
	
	func setTransactionSeries(_ series: TransactionSeries) {
		self.transactionSeries = series
		updateUI(self)
	}
	
	private var incomeExpenseSeries: IncomeExpenseTransactionSeries? {
		return transactionSeries as? IncomeExpenseTransactionSeries
	}
	
	
	@IBOutlet weak var expensePopup: NSPopUpButton!
	@IBOutlet weak var expenseAmountTextField: NSTextField!
	@IBOutlet weak var expenseDescriptionTextField: NSTextField!
	@IBOutlet weak var datePicker: NSDatePicker!
	@IBOutlet weak var incomePopup: NSPopUpButton!
	@IBOutlet weak var incomeAmountLabel: NSTextField!
	@IBOutlet weak var incomeDescriptionLabel: NSTextField!
	@IBOutlet weak var okButton: NSButton!
	
	override func windowDidLoad() {
        super.windowDidLoad()
		//expenseAmountTextField.delegate = self
		expenseDescriptionTextField.delegate = self
        initPopupLists()
		updateUI(self)
    }
	
	private func initPopupLists() {
		let eTypes = TransactionType.transactionTypesForExpense()
		expensePopup.removeAllItems()
		for transactionType in eTypes {
			expensePopup.addItem(withTitle: transactionType.symbol + " " + transactionType.name)
			let item = expensePopup.lastItem!
			item.tag = transactionType.id
		}

		let iTypes = TransactionType.transactionTypesForIncome()
		incomePopup.removeAllItems()
		for transactionType in iTypes {
			incomePopup.addItem(withTitle: transactionType.symbol + " " + transactionType.name)
			let item = incomePopup.lastItem!
			item.tag = transactionType.id
		}
	}

	private func updateUI(_ sender: Any?) {
		guard let _ = okButton else { return }
		if let ies = incomeExpenseSeries {
			datePicker.dateValue = ies.date
			
			expensePopup.selectItem(withTag: ies.primaryTransaction.transactionType.id)
			incomePopup.selectItem(withTag: ies.secondaryTransaction.transactionType.id)
			
			let tfSender = sender as? NSTextField
			if expenseAmountTextField != tfSender {
				expenseAmountTextField.stringValue = ies.amountString
			}
			if expenseDescriptionTextField != tfSender {
				expenseDescriptionTextField.stringValue = ies.description
			}
			
			incomeAmountLabel.floatValue = ies.secondaryTransaction.amount
			incomeDescriptionLabel.stringValue = ies.description
			
			okButton.isEnabled = isOKEnabled
		}
	}
	
	private var isOKEnabled: Bool {
		if let ts = transactionSeries {
			return ts.isValid
		}
		return false
	}
	
	func controlTextDidChange(_ obj: Notification) {
		if let tfSender = obj.object as? NSTextField {
			if tfSender == expenseAmountTextField {
				amountChanged(tfSender)
			}
			if tfSender == expenseDescriptionTextField {
				descriptionChanged(tfSender)
			}
		}
	}

	@IBAction func expenseTypeSelected(_ sender: NSPopUpButton) {
		if let ies = incomeExpenseSeries {
			let tt = TransactionType.transactionType(forCode: sender.selectedItem?.tag ?? 0) ?? TransactionType.defaultExpense
			ies.primaryTransaction.transactionType = tt
		}
		updateUI(sender)
	}
	
	@IBAction func incomeTypeChanged(_ sender: NSPopUpButton) {
		if let ies = incomeExpenseSeries {
			let tt = TransactionType.transactionType(forCode: sender.selectedItem?.tag ?? 0) ?? TransactionType.defaultIncome
			ies.secondaryTransaction.transactionType = tt
		}
		updateUI(sender)
	}
	
	@IBAction func amountChanged(_ sender: NSTextField) {
		let cleanAmount = sender.stringValue.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
		transactionSeries.amountString = cleanAmount
		updateUI(sender)
	}
	
	@IBAction func descriptionChanged(_ sender: NSTextField) {
		transactionSeries.description = sender.stringValue
		updateUI(sender)
	}
	
	@IBAction func dateChanged(_ sender: NSDatePicker) {
		transactionSeries.date = sender.dateValue
		updateUI(sender)
	}
	@IBAction func ok(_ sender: Any) {
		self.window?.makeFirstResponder(nil)
		self.window?.sheetParent?.endSheet(self.window!)
	}
	
	@IBAction func cancel(_ sender: Any) {
		self.window?.sheetParent?.endSheet(self.window!, returnCode: .abort)
	}
	
}
