//
//  CategoryViewController.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-05-30.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa
import Combine

class CategoryViewController: FFFViewController {
	@IBOutlet weak var outlineView: NSOutlineView!
	
	private var treeData = Dictionary<Category, [FFFTransaction]>()
	private var categories = [Category]()
	private var storage = Set<AnyCancellable>()
	
	override func clearSelection() {
		if outlineView != nil {
			outlineView.deselectAll(self)
		}
		super.clearSelection()
	}
	
	private func makeTreeData(summary cs: CategorySummary, transactions: [FFFTransaction]) {
		self.treeData.removeAll()
		for cat in cs.categories {
			treeData[cat] = transactions.filter { $0.transactionType.id == cat.tt }
		}
		self.categories = cs.categories.sorted { $0.ttName < $1.ttName }
	}
	
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
		outlineView.delegate = self
		outlineView.dataSource = self
		
		// Double-click to edit
		outlineView.target = self
		outlineView.doubleAction = #selector(doubleAction(_:))
		
		let p1 = NotificationCenter.default.publisher(for: .stateChange_MonthlyTransactions)
			.compactMap { $0.userInfo?["value"] as? [FFFTransaction] }
		
		let p2 = NotificationCenter.default.publisher(for: .stateChange_MonthlyCategories)
			.compactMap { $0.userInfo?["value"] as? CategorySummary }

		Publishers.Zip(p1, p2)
			.receive(on: DispatchQueue.main)
			.sink { transactions, cs in
				self.makeTreeData(summary: cs, transactions: transactions)
				self.outlineView.reloadData()
		}.store(in: &self.storage)
	}
	
	@objc func doubleAction(_ outlineView:NSOutlineView) {
		let item = outlineView.item(atRow: outlineView.clickedRow)
		if let t = item as? FFFTransaction {
			NotificationCenter.default.post(name: .showEditForm,
											object: self,
											userInfo: ["t": t])
		}
	}

	override func viewWillAppear() {
		super.viewWillAppear()
	}
}


extension CategoryViewController: NSOutlineViewDataSource {
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		var n = 0
		if item == nil {
			// How many root nodes?
			n = categories.count
		}
		else if let cat = item as? Category {
			// How many transactions in category?
			n = treeData[cat]?.count ?? 0
		}
		return n
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		if let cat = item as? Category {
			// Transaction row
			return treeData[cat]![index]
		}
		else {
			// This is a child of root (nil) -> Category row
			return categories[index]
		}
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		return item is Category
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
		let image: NSImage? = nil
		var text: String = ""
		var cellIdentifier: String = ""

		let currFormatter = NumberFormatter()
		currFormatter.numberStyle = .currency

		let pctFormatter = NumberFormatter()
		pctFormatter.numberStyle = .percent
		
		var tagAsIncome: Bool = false
		
		if let cat = item as? Category {
			if tableColumn == outlineView.tableColumns[0] {
				let emoji = TransactionType.transactionType(forCode: cat.tt)?.symbol ?? "💥"
				text = emoji + " " + cat.ttName
//				image = TransactionType.transactionType(forCode: cat.transactionTypeID)?.icon
				cellIdentifier = CellID.TransactionType
				tagAsIncome = cat.isExpense == false
			}
			else if tableColumn == outlineView.tableColumns[1] {
				text = currFormatter.string(from: NSNumber(value: cat.amount))!
				cellIdentifier = CellID.Amount
				tagAsIncome = cat.isExpense == false
			}
			else if tableColumn == outlineView.tableColumns[2] {
				text = pctFormatter.string(from: NSNumber(value: cat.percent))!
				cellIdentifier = CellID.Percent
			}
		}
		else if let t = item as? FFFTransaction {
			if tableColumn == outlineView.tableColumns[0] {
				text = t.description
				cellIdentifier = CellID.TransactionType
			}
			else if tableColumn == outlineView.tableColumns[1] {
				text = currFormatter.string(from: NSNumber(value: t.amount))!
				cellIdentifier = CellID.Amount
				tagAsIncome = t.transactionType.isExpense == false
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
			if tagAsIncome {
				textField.textColor = NSColor(named: NSColor.Name("incomeTextColor")) ?? NSColor.purple
			}
			else {
				textField.textColor = NSColor.textColor
			}
		}
		if let imageView = view?.imageView {
			imageView.image = image
		}

		return view
	}
	
	func outlineViewSelectionDidChange(_ notification: Notification) {
		let t = outlineView.item(atRow: outlineView.selectedRow) as? FFFTransaction
		app.selectedTransaction = t
	}
}
