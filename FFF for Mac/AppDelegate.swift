//
//  AppDelegate.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-02-13.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa
import Combine

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
	static var appVersion:String {
		if let dict = Bundle.main.infoDictionary {
			let nsObject = dict["CFBundleShortVersionString"] as AnyObject
			return nsObject as! String
		}
		return "Error"
	}

	static let unitsYMD: Set<Calendar.Component> = [.month, .year, .day]
	static let unitsYM: Set<Calendar.Component> = [.month, .year]
	@IBOutlet var duplicateMenuItem: NSMenuItem!
	@IBOutlet weak var deleteMenuItem: NSMenuItem!
	
	var state = AppState()
	var storage = Set<AnyCancellable>()
	
	// Convenience referring to state object -- for now
	var currentDate: Date {
		get {
			return self.state.currentDate
		}
		set {
			self.state.currentDate = newValue
		}
	}
	// Convenience referring to state object -- for now
	var currentDateComponents: (year:Int, month:Int, day:Int) {
		return state.currentDateComponents
	}
	
	func setDayOfMonth(_ day:Int) {
		var components = Calendar.current.dateComponents(AppDelegate.unitsYMD, from: currentDate)
		components.setValue(day, for: .day)
		if let newDate = Calendar.current.date(from: components) {
			currentDate = newDate
		}
	}
	
	var selectedTransaction: FFFTransaction?

	func application(_ sender: NSApplication, openFile filename: String) -> Bool {
		print("Opening file \(filename)")
		NotificationCenter.default.post(name: .openBankFile,
										object: self,
										userInfo: ["filename": filename])
		return true
	}
	
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// For debugging purposes, set currentDate to a date with transactions
//		setYear(2007)
//		setMonth(8)
//		setDayOfMonth(27)
		// Also for debugging
		let _ = TransactionType.transactionTypes
		
		// Get the list of transaction types
		let req = RestGateway.shared.createRequestGetTransactionTypes(category: .All)
		URLSession.shared.dataTaskPublisher(for: req)
			.map { $0.data }
			.replaceError(with: Data())
			.decode(type: [TransactionType].self, decoder: JSONDecoder())
			.replaceError(with: [TransactionType]())
			.sink { ttList in
				if ttList.count > 0 {
					TransactionType.transactionTypes = ttList
				}
		}.store(in: &self.storage)
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}

	// MARK: Saving template transactions
	
	private static let max_recent_count = 10
	private enum TransactionKey: String {
		case Amount = "amount"
		case TransactionType = "tt"
		case Description = "description"
	}
	struct TransactionTemplate: Equatable {
		init(dict: NSDictionary) {
			let tempAmount = Float(dict[TransactionKey.Amount.rawValue] as! String)
			self.amount = tempAmount!
			self.description = dict[TransactionKey.Description.rawValue] as? String
			let tempTT = Int(dict[TransactionKey.TransactionType.rawValue] as! String)
			self.tt = tempTT!
		}
		init(transaction:FFFTransaction) {
			tt = transaction.transactionType.id
			amount = transaction.amount
			description = transaction.description
		}
		var tt: Int = 0
		var amount: Float = 0.0
		var description: String?
		var transaction: FFFTransaction {
			var t = FFFTransaction()
			t.amount = amount
			t.transactionType = TransactionType.transactionType(forCode: tt) ?? TransactionType.defaultExpense
			t.description = description ?? ""
			return t
		}
		var dictionary: NSDictionary {
			let dict = NSMutableDictionary()
			dict[TransactionKey.Amount.rawValue] = String(self.amount)
			dict[TransactionKey.TransactionType.rawValue] = String(self.tt)
			dict[TransactionKey.Description.rawValue] = self.description
			return dict
		}
	}
	func saveRecentTransaction(_ transaction: FFFTransaction) {
		let template = TransactionTemplate(transaction: transaction)
		
		// If this transaction is already in the list, remove it
		var recents = recentTransactionTemplates
		for (index, recentT) in recents.enumerated() {
			if template == recentT {
				recents.remove(at: index)
				break
			}
		}
		
		// Put at the first spot in the list
		recents.insert(template, at: 0)
		
		// If we have more than the max, then trim the list
		while recents.count > AppDelegate.max_recent_count {
			recents.removeLast()
		}
		
		// Store in UserDefaults
		let content = NSMutableArray()
		for templateTransaction in recents {
			content.add(templateTransaction.dictionary)
		}
		UserDefaults.standard.set(content, forKey: DefaultsKey.RecentTransactions.rawValue)
	}
	
	private var recentTransactionTemplates: [TransactionTemplate] {
		var recents = [TransactionTemplate]()
		
		// Retrieve from UserDefaults
		if let listOfDictionaries = UserDefaults.standard.array(forKey: DefaultsKey.RecentTransactions.rawValue) {
			for info in listOfDictionaries {
				if let dict = info as? NSDictionary {
					let template = TransactionTemplate(dict: dict)
					recents.append(template)
				}
			}
		}
		
		return recents
	}
	
	var recentTransactions: [FFFTransaction] {
		return recentTransactionTemplates.map { $0.transaction }
	}

}

