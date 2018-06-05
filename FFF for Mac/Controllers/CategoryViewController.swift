//
//  CategoryViewController.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-05-30.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa

class CategoryViewController: FFFViewController {
	@IBOutlet weak var outlineView: NSOutlineView!
	
	private var categorySummary: CategorySummary?
	
	private func requestSummary() {
		if Gateway.shared.isLoggedIn {
			let components = app.currentDateComponents
			Gateway.shared.getCategorySummary(forYear: components.year, month: components.month) {[weak self] message in
				if var cs = message.categorySummary {
					Gateway.shared.getTransactions(forYear: components.year, month: components.month) { [weak self] message in
						if let transactions = message.transactions {
							cs.assignTransactions(transactions)
							self?.categorySummary = cs
							DispatchQueue.main.async{
								self?.outlineView.reloadData()
							}
						}
					}
				}
			}
		}
	}
	
	// MARK: Notifications
	override func loginNotificationReceived(_ note: Notification) {
		self.requestSummary()
	}
	
	override func logoutNotificationReceived(_ note: Notification) {
		self.categorySummary = nil
		outlineView.reloadData()
	}
	
	override func currentDateChanged(_ notification: Notification) {
		self.requestSummary()
	}

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
		outlineView.delegate = self
		outlineView.dataSource = self
	}
	
	override func viewWillAppear() {
		super.viewWillAppear()
	}
}


extension CategoryViewController: NSOutlineViewDataSource {
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		var n = 0
		if let sum = categorySummary {
			if item == nil {
				n = sum.expenses.count + sum.income.count
			}
			else if let cat = item as? Category {
				n = cat.transactions.count
			}
		}
		return n
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		let sum = categorySummary!
		if let cat = item as? Category {
			return cat.transactions[index]
		}
		else {
			// This is a child of root (nil)
			if index >= sum.expenses.count {
				return sum.income[index - sum.expenses.count]
			}
			return sum.expenses[index]
		}
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		if item is Category {
			return true
		}
		return false
	}
}

extension CategoryViewController: NSOutlineViewDelegate {
	fileprivate struct CellID {
		static let Amount = "AmountCellID"
		static let TransactionType = "TransactionTypeCellID"
		static let Percent = "PercentCellID"
		static let Description = "DescriptionCellID"
	}

	func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
		var view: NSTableCellView?
		var image: NSImage?
		var text: String = ""
		var cellIdentifier: String = ""

		let currFormatter = NumberFormatter()
		currFormatter.numberStyle = .currency

		let pctFormatter = NumberFormatter()
		pctFormatter.numberStyle = .percent
		
		if let cat = item as? Category {
			if tableColumn == outlineView.tableColumns[0] {
				let emoji = TransactionType.transactionType(forCode: cat.transactionTypeID)?.emoji ?? "💥"
				text = emoji + " " + cat.transactionTypeName
				image = TransactionType.transactionType(forCode: cat.transactionTypeID)?.icon
				cellIdentifier = CellID.TransactionType
			}
			else if tableColumn == outlineView.tableColumns[1] {
				text = currFormatter.string(from: NSNumber(value: cat.amount))!
				cellIdentifier = CellID.Amount
			}
			else if tableColumn == outlineView.tableColumns[2] {
				text = pctFormatter.string(from: NSNumber(value: cat.percent))!
				cellIdentifier = CellID.Percent
			}
		}
		else if let t = item as? Transaction {
			if tableColumn == outlineView.tableColumns[0] {
				text = t.description ?? ""
				cellIdentifier = CellID.TransactionType
			}
			else if tableColumn == outlineView.tableColumns[1] {
				text = currFormatter.string(from: NSNumber(value: t.amount))!
				cellIdentifier = CellID.Amount
			}
			else if tableColumn == outlineView.tableColumns[2] {
				text = ""
				cellIdentifier = CellID.Percent
			}
		}
		
		let id = NSUserInterfaceItemIdentifier(cellIdentifier)
		
		view = outlineView.makeView(withIdentifier: id, owner: self) as? NSTableCellView
		if let textField = view?.textField {
			textField.stringValue = text
			//textField.sizeToFit()
		}
		if let imageView = view?.imageView {
			imageView.image = image
		}

		return view
	}
}
