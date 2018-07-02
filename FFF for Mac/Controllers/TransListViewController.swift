//
//  GridViewController.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-02-21.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa

class TransListViewController: FFFViewController {
	@IBOutlet weak var tableView: NSTableView!
	
	var searchString: String? {
		didSet {
			print("TransListViewController searchString set to \(String(describing: searchString))")
			requestTransactions()
		}
	}
	private var transactions = [Transaction]()

	private var savedSortDescriptors: [NSSortDescriptor]?
	
	private func requestTransactions() {
		if CachingGateway.shared.isLoggedIn {
			if searchString == nil || searchString!.trimmingCharacters(in: CharacterSet.whitespaces) == "" {
				// Regular list of monthly transactions
				let components = app.currentDateComponents
				CachingGateway.shared.getTransactions(forYear:components.year, month: components.month) {[weak self] message in
					if let t = message.transactions {
						self?.transactions = t
						DispatchQueue.main.async {
							if self != nil && self!.savedSortDescriptors != nil {
								self!.tableView.sortDescriptors = self!.savedSortDescriptors!
								self!.savedSortDescriptors = nil
							}
							else {
								self?.tableView.reloadData()
							}
						}
					}
				}
			}
			else {
				// Search results
				CachingGateway.shared.getSearchResults(searchString!) {[weak self] message in
					if let t = message.transactions {
						self?.transactions = t
						DispatchQueue.main.async{
							if self?.savedSortDescriptors == nil {
								// This is the first search. We are going to save the sorting
								// so that when we stop searching, we can revert it back.
								self?.savedSortDescriptors = self?.tableView.sortDescriptors
							}
							self?.tableView.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
							//self?.tableView.reloadData()
						}
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
	
	override func currentDateChanged(_ notification: Notification) {
		requestTransactions()
	}
	
	override func dataUpdated(_ notification: Notification) {
		requestTransactions()
	}
	
	// MARK: ViewController

    override func viewDidLoad() {
        super.viewDidLoad()
		
		//print("TransListViewController viewDidLoad")
		
		// Hook up the tableview delegate and datasource
		tableView.delegate = self
		tableView.dataSource = self
		
		// Create sort descriptors
		let descriptorAmount = NSSortDescriptor(key: "amount", ascending: true)
		let descriptorDate = NSSortDescriptor(key: "date", ascending: true)
		let descriptorDesc = NSSortDescriptor(key: "description", ascending: true)
		let descriptorType = NSSortDescriptor(key: "transactionType.description", ascending: true)

		tableView.tableColumns[0].sortDescriptorPrototype = descriptorDate
		tableView.tableColumns[1].sortDescriptorPrototype = descriptorAmount
		tableView.tableColumns[2].sortDescriptorPrototype = descriptorType
		tableView.tableColumns[3].sortDescriptorPrototype = descriptorDesc
		
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

	override func viewWillAppear() {
		super.viewWillAppear()
	}
}

extension TransListViewController: NSTableViewDataSource {
	func numberOfRows(in tableView: NSTableView) -> Int {
		return transactions.count
	}
	
	func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
		// Array of NSSortDescriptor. The most recent column clicked on is first.
		//print("sortDescriptorsDidChange")
		guard let sortDescriptor = tableView.sortDescriptors.first else {
			tableView.reloadData()
			return
		}
		switch sortDescriptor.key {
		case "amount":
			transactions.sort {lhs, rhs in
				if sortDescriptor.ascending {
					return lhs.amount < rhs.amount
				}
				return lhs.amount > rhs.amount
			}
		case "date":
			transactions.sort {lhs, rhs in
				if sortDescriptor.ascending {
					return lhs.date < rhs.date
				}
				return lhs.date > rhs.date
			}
		case "transactionType.description":
			transactions.sort {lhs, rhs in
				if sortDescriptor.ascending {
					return lhs.transactionType!.description < rhs.transactionType!.description
				}
				return lhs.transactionType!.description > rhs.transactionType!.description
			}
		default:
			transactions.sort {lhs, rhs in
				if sortDescriptor.ascending {
					return lhs.description ?? "" < rhs.description ?? ""
				}
				return lhs.description ?? "" > rhs.description ?? ""
			}
		}
		tableView.reloadData()
	}

}

extension TransListViewController: NSTableViewDelegate {

	fileprivate struct CellID {
		static let Amount = "AmountCellID"
		static let TransactionType = "TransactionTypeCellID"
		static let Date = "DateCellID"
		static let Description = "DescriptionCellID"
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		var image: NSImage?
		var text: String = ""
		var cellIdentifier: String = ""
		
		if row >= transactions.count {
			return nil
		}
		
		let dateFormatter = DateFormatter()
		dateFormatter.dateStyle = .long
		dateFormatter.timeStyle = .none
		
		let currFormatter = NumberFormatter()
		currFormatter.numberStyle = .currency
		
		let t = transactions[row]
		
		if tableColumn == tableView.tableColumns[0] {
			text = dateFormatter.string(from: t.date)
			cellIdentifier = CellID.Date
		}
		else if tableColumn == tableView.tableColumns[1] {
			text = currFormatter.string(from: NSNumber(value: t.amount))!
			cellIdentifier = CellID.Amount
		}
		else if tableColumn == tableView.tableColumns[2] {
			text = t.transactionType!.emoji + " " + t.transactionType!.description
//			image = t.transactionType!.icon
			cellIdentifier = CellID.TransactionType
		}
		else if tableColumn == tableView.tableColumns[3] {
			text = t.description ?? ""
			cellIdentifier = CellID.Description
		}
		
		let id = NSUserInterfaceItemIdentifier(cellIdentifier)
		if let cell = tableView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView {
			cell.textField?.stringValue = text
			cell.imageView?.image = image ?? nil
			return cell
		}
		return nil
	}

}
