//
//  CheckerViewController.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-06-15.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa

class CheckerViewController: FFFViewController {

	@IBOutlet weak var dragAndDropLabel: NSTextField!
	@IBOutlet weak var outlineView: NSOutlineView!
	
	var matches: [TransactionMatch]?
	
	override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
		if let cdv = view as? CheckerDragView {
			cdv.delegate = self
		}
		NotificationCenter.default.addObserver(self,
											   selector: #selector(openBankFileNotificationReceived(_:)),
											   name: NSNotification.Name(rawValue: Notifications.OpenBankFile.rawValue),
											   object: nil)
    }
	
	@objc func openBankFileNotificationReceived(_ notification: Notification) {
		// userinfo has the name of the file at key "filename"
		if let userInfo = notification.userInfo, let filename = userInfo["filename"] as? String {
			let url = URL(fileURLWithPath: filename)
			tabViewController?.selectedTabViewItemIndex = 3  // Show this
			self.openCSV(url)
		}
	}
}

extension CheckerViewController: CheckerDragViewDelegate {
	@discardableResult
	func openCSV(_ url: URL) -> Bool {
		print("Will open CSV with url \(url)")
		var bankTransactions = [BankTransaction]()
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "MM/dd/yyyy"
		
		do {
			let csvString = try String(contentsOf: url)
			let csv = CSwiftV(with: csvString)
			for (index, row) in csv.keyedRows!.enumerated() {
				let bt = BankTransaction(id: index,
										 date: dateFormatter.date(from: row["Transaction Date"]!)!,
										 desc1: row["Description 1"]!,
										 desc2: row["Description 2"],
										 amount: Float(row["CAD$"]!)!)
				bankTransactions.append(bt)
			}
		}
		catch {
			print("Error opening CSV file: \(error)")
		}
		
		
		return true
	}
}
