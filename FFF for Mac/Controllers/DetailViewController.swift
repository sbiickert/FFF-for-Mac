//
//  DetailViewController.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-02-17.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa
import Combine

class DetailViewController: FFFViewController {
	
	@IBOutlet weak var tableView: NSTableView!
	
	override func clearSelection() {
		if tableView != nil {
			tableView.deselectAll(self)
		}
		super.clearSelection()
	}
	private var transactions = [FFFTransaction]()
	private var storage = Set<AnyCancellable>()

	// MARK: ViewController

    override func viewDidLoad() {
        super.viewDidLoad()
		
		// Hook up the tableview delegate and datasource
		tableView.delegate = self
		tableView.dataSource = self
		
		// Double-click to edit
		tableView.target = self
		tableView.doubleAction = #selector(doubleAction(_:))
		
		NotificationCenter.default.publisher(for: .stateChange_DailyTransactions)
			.compactMap { $0.userInfo?["value"] as? [FFFTransaction] }
			.receive(on: DispatchQueue.main)
			.sink { transactions in
				self.transactions = transactions
				self.tableView.reloadData()
		}.store(in: &self.storage)
    }
	
	@objc func doubleAction(_ tableView:NSTableView) {
		if transactions.indices.contains(tableView.clickedRow) {
			let t = transactions[tableView.clickedRow]
			NotificationCenter.default.post(name: .showEditForm,
											object: self,
											userInfo: ["t": t])
		}
	}
}

extension DetailViewController: NSTableViewDataSource {
	func numberOfRows(in tableView: NSTableView) -> Int {
		return transactions.count
	}
}

extension DetailViewController: NSTableViewDelegate {
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		let cellIdentifier: String = "DetailCellID"
		let id = NSUserInterfaceItemIdentifier(cellIdentifier)
		let t = transactions[row]
		
		var textColor = NSColor.controlTextColor
		if t.transactionType.isExpense == false {
			textColor = NSColor(named: NSColor.Name("incomeTextColor")) ?? NSColor.purple
		}

		let currFormatter = NumberFormatter()
		currFormatter.numberStyle = .currency

		if let cell = tableView.makeView(withIdentifier: id, owner: nil) as? DetailTableCellView {
			cell.amountLabel.stringValue = currFormatter.string(from: NSNumber(value: t.amount))!
			cell.amountLabel.textColor = textColor
			cell.descriptionLabel.stringValue = t.description
			cell.iconLabel.stringValue = t.transactionType.symbol
			cell.transactionTypeNameLabel.stringValue = self.transactionTypeLabel(for: t)
			cell.transactionTypeNameLabel.textColor = textColor
			return cell
		}
		return nil
	}
	
	private func transactionTypeLabel(for transaction:FFFTransaction) -> String {
		var label = transaction.transactionType.name
		if transaction.seriesID != nil {
			label = FFFTransaction.seriesTag + " " + label
		}
		return label
	}
	
	func tableViewSelectionDidChange(_ notification: Notification) {
		if tableView.selectedRow >= 0 {
			let t = transactions[tableView.selectedRow]
			app.selectedTransaction = t
		}
		else {
			// No row selected
			app.selectedTransaction = nil
		}
	}
}
