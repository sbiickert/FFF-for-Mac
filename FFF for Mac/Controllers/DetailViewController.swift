//
//  DetailViewController.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-02-17.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa

class DetailViewController: NSViewController {
	
	@IBOutlet weak var tableView: NSTableView!
	
	private var transactions = [Transaction]()
	private var app:AppDelegate {
		get {
			return NSApplication.shared.delegate as! AppDelegate
		}
	}
	
	private func requestTransactions() {
		if Gateway.shared.isLoggedIn {
			let components = app.currentDateComponents
			Gateway.shared.getTransactions(forYear:components.year, month: components.month, day: components.day) {[weak self] message in
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
	@objc func loginNotificationReceived(_ note: NSNotification) {
		requestTransactions()
	}
	
	@objc func logoutNotificationReceived(_ note: NSNotification) {
		self.transactions.removeAll()
		tableView.reloadData()
	}
	
	@objc func dateChangeNotificationReceived(_ note: NSNotification) {
		requestTransactions()
	}
	
	// MARK: ViewController

    override func viewDidLoad() {
        super.viewDidLoad()
		
		// Hook up the tableview delegate and datasource
		tableView.delegate = self
		tableView.dataSource = self
		// Subscribe to notifications on date change and login/logout
		NotificationCenter.default.addObserver(self,
											   selector: #selector(loginNotificationReceived(_:)),
											   name: NSNotification.Name(rawValue: Notifications.LoginResponse.rawValue),
											   object: nil)
		NotificationCenter.default.addObserver(self,
											   selector: #selector(logoutNotificationReceived(_:)),
											   name: NSNotification.Name(rawValue: Notifications.LoginResponse.rawValue),
											   object: nil)
		NotificationCenter.default.addObserver(self,
											   selector: #selector(dateChangeNotificationReceived(_:)),
											   name: NSNotification.Name(rawValue: Notifications.CurrentDateChanged.rawValue),
											   object: nil)
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
			cell.iconImageButton.title = (t.transactionType?.emoji)!
			cell.transactionTypeNameLabel.stringValue = t.transactionType?.description ?? ""
			return cell
		}
		return nil
	}
}
