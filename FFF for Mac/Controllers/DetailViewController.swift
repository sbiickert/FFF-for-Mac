//
//  DetailViewController.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-02-17.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa

class DetailViewController: FFFViewController {
	
	@IBOutlet weak var tableView: NSTableView!
	
	override func clearSelection() {
		if tableView != nil {
			tableView.deselectAll(self)
		}
		super.clearSelection()
	}
	private var transactions = [Transaction]()
	
	private func requestTransactions() {
		if CachingGateway.shared.isLoggedIn {
			let components = app.currentDateComponents
			CachingGateway.shared.getTransactions(forYear:components.year, month: components.month, day: components.day) {[weak self] message in
				if let t = message.transactions {
					self?.transactions = t
					DispatchQueue.main.async{
						self?.tableView.reloadData()
					}
				}
			}
		}
	}
	
	// MARK: Notifications
	override func loginNotificationReceived(_ note: Notification) {
		requestTransactions()
	}
	
	override func logoutNotificationReceived(_ note: Notification) {
		self.transactions.removeAll()
		tableView.reloadData()
	}
	
	override func currentDateChanged(_ note: Notification) {
		requestTransactions()
	}
	
	override func currentDayChanged(_ note: Notification) {
		requestTransactions()
	}
	
	override func dataUpdated(_ notification: Notification) {
		requestTransactions()
	}

	// MARK: ViewController

    override func viewDidLoad() {
        super.viewDidLoad()
		
		// Hook up the tableview delegate and datasource
		tableView.delegate = self
		tableView.dataSource = self
		
		// Double-click to edit
		tableView.target = self
		tableView.doubleAction = #selector(doubleAction(_:))
    }
	
	@objc func doubleAction(_ tableView:NSTableView) {
		let t = transactions[tableView.clickedRow]
		NotificationCenter.default.post(name: NSNotification.Name(Notifications.ShowEditForm.rawValue),
										object: self,
										userInfo: ["t": t])
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
		
		let currFormatter = NumberFormatter()
		currFormatter.numberStyle = .currency

		if let cell = tableView.makeView(withIdentifier: id, owner: nil) as? DetailTableCellView {
			cell.amountLabel.stringValue = currFormatter.string(from: NSNumber(value: t.amount))!
			cell.descriptionLabel.stringValue = t.description ?? ""
			cell.iconLabel.stringValue = (t.transactionType?.emoji)!
			cell.transactionTypeNameLabel.stringValue = self.transactionTypeLabel(for: t)
			return cell
		}
		return nil
	}
	
	private func transactionTypeLabel(for transaction:Transaction) -> String {
		var label = transaction.transactionType?.description ?? ""
		if transaction.seriesID != nil {
			label = Transaction.seriesTag + " " + label
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
