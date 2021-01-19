//
//  GridViewController.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-02-21.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa
import Combine

class TransListViewController: FFFViewController {
	@IBOutlet weak var tableView: NSTableView!
	
	override func clearSelection() {
		if tableView != nil {
			tableView.deselectAll(self)
		}
		super.clearSelection()
	}
	
	var searchString: String? {
		didSet {
			print("TransListViewController searchString set to \(String(describing: searchString))")
			doSearch()
		}
	}
	var isSearchStringEmpty: Bool {
		return searchString == nil || searchString!.trimmingCharacters(in: CharacterSet.whitespaces) == ""
	}
	
	private var transactions = [FFFTransaction]()
	private var searchTransactions = [FFFTransaction]()
	
	private var storage = Set<AnyCancellable>()

	private var savedSortDescriptors: [NSSortDescriptor]?
	
	private func doSearch() {
		self.searchTransactions = [FFFTransaction]()
		if isSearchStringEmpty {
			// Empty search: Revert to regular list of monthly transactions
			DispatchQueue.main.async {
				if self.savedSortDescriptors != nil {
					self.tableView.sortDescriptors = self.savedSortDescriptors!
					self.savedSortDescriptors = nil
				}
				else {
					self.tableView.reloadData()
				}
			}
		}
		else {
			// Search results
			let req = RestGateway.shared.createRequestGetSearchResults(searchString!)
			URLSession.shared.dataTaskPublisher(for: req)
				.map { $0.data }
				.replaceError(with: Data())
				.decode(type: [CodableTransaction].self, decoder: JSONDecoder())
				.replaceError(with: [CodableTransaction]())
				.map { ctArray in
					ctArray.map { $0.transaction }
				}
				.receive(on: DispatchQueue.main)
				.sink { tArray in
					self.searchTransactions = tArray
					if self.savedSortDescriptors == nil {
						// This is the first search. We are going to save the sorting
						// so that when we stop searching, we can revert it back.
						self.savedSortDescriptors = self.tableView.sortDescriptors
					}
					self.tableView.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
			}.store(in: &self.storage)
		}
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
		
		NotificationCenter.default.publisher(for: .stateChange_MonthlyTransactions)
			.compactMap { $0.userInfo?["value"] as? [FFFTransaction] }
			.receive(on: DispatchQueue.main)
			.sink { transactions in
				self.transactions = transactions
				self.doSearch()
		}.store(in: &self.storage)
	}
	
	@objc func doubleAction(_ tableView:NSTableView) {
		let row = tableView.clickedRow
		if row >= 0 { // -1 is double-click on the header
			let t = isSearchStringEmpty ? transactions[row] : searchTransactions[row]
			NotificationCenter.default.post(name: .showEditForm,
											object: self,
											userInfo: ["t": t])
		}
	}

	override func viewWillAppear() {
		super.viewWillAppear()
	}
}

extension TransListViewController: NSTableViewDataSource {
	func numberOfRows(in tableView: NSTableView) -> Int {
		return isSearchStringEmpty ? transactions.count : searchTransactions.count
	}
	
	func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
		// Array of NSSortDescriptor. The most recent column clicked on is first.
		//print("sortDescriptorsDidChange")
		guard let sortDescriptor = tableView.sortDescriptors.first else {
			tableView.reloadData()
			return
		}

		// Sort functions
		func sortByAmount(lhs: FFFTransaction, rhs: FFFTransaction) -> Bool {
			if sortDescriptor.ascending {
				return lhs.amount < rhs.amount
			}
			return lhs.amount > rhs.amount
		}
		func sortByDate(lhs: FFFTransaction, rhs: FFFTransaction) -> Bool {
			if sortDescriptor.ascending {
				return lhs.date < rhs.date
			}
			return lhs.date > rhs.date
		}
		func sortByTTDesc(lhs: FFFTransaction, rhs: FFFTransaction) -> Bool {
			if sortDescriptor.ascending {
				return lhs.transactionType.name < rhs.transactionType.name
			}
			return lhs.transactionType.name > rhs.transactionType.name
		}
		func sortByDesc(lhs: FFFTransaction, rhs: FFFTransaction) -> Bool {
			if sortDescriptor.ascending {
					return lhs.description < rhs.description
				}
			return lhs.description > rhs.description
		}

		// Sort both monthly transactions and search results. Only one is showing.
		switch sortDescriptor.key {
		case "amount":
			transactions.sort(by: sortByAmount(lhs:rhs:))
			searchTransactions.sort(by: sortByAmount(lhs:rhs:))
		case "date":
			transactions.sort(by: sortByDate(lhs:rhs:))
			searchTransactions.sort(by: sortByDate(lhs:rhs:))
		case "transactionType.description":
			transactions.sort(by: sortByTTDesc(lhs:rhs:))
			searchTransactions.sort(by: sortByTTDesc(lhs:rhs:))
		default:
			transactions.sort(by: sortByDesc(lhs:rhs:))
			searchTransactions.sort(by: sortByDesc(lhs:rhs:))
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
		let image: NSImage? = nil
		var text: String = ""
		var textColor = NSColor.controlTextColor
		var cellIdentifier: String = ""
		
		let limit = isSearchStringEmpty ? transactions.count : searchTransactions.count
		if row >= limit {
			return nil
		}
		
		let dateFormatter = DateFormatter()
		dateFormatter.dateStyle = .long
		dateFormatter.timeStyle = .none
		
		let currFormatter = NumberFormatter()
		currFormatter.numberStyle = .currency
		
		let t = isSearchStringEmpty ? transactions[row] : searchTransactions[row]
		
		if tableColumn == tableView.tableColumns[0] {
			text = dateFormatter.string(from: t.date)
			cellIdentifier = CellID.Date
		}
		else if tableColumn == tableView.tableColumns[1] {
			text = currFormatter.string(from: NSNumber(value: t.amount))!
			if t.transactionType.isExpense == false {
				textColor = NSColor(named: NSColor.Name("incomeTextColor")) ?? NSColor.purple
			}
			cellIdentifier = CellID.Amount
		}
		else if tableColumn == tableView.tableColumns[2] {
			text = t.transactionType.symbol + " " + t.transactionType.name
//			image = t.transactionType!.icon
			if t.transactionType.isExpense == false {
				textColor = NSColor(named: NSColor.Name("incomeTextColor")) ?? NSColor.purple
			}
			cellIdentifier = CellID.TransactionType
		}
		else if tableColumn == tableView.tableColumns[3] {
			text = t.description
			cellIdentifier = CellID.Description
		}
		
		let id = NSUserInterfaceItemIdentifier(cellIdentifier)
		if let cell = tableView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView {
			cell.textField?.stringValue = text
			cell.textField?.textColor = textColor
			cell.imageView?.image = image ?? nil
			return cell
		}
		return nil
	}

	func tableViewSelectionDidChange(_ notification: Notification) {
		if tableView.selectedRow >= 0 {
			let row = tableView.selectedRow
			let t = isSearchStringEmpty ? transactions[row] : searchTransactions[row]
			app.selectedTransaction = t
		}
		else {
			// No row selected
			app.selectedTransaction = nil
		}
	}
}
