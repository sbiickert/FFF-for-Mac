//
//  LocalGateway.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-06-29.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Foundation

class CachingGateway: Gateway {
	
	static let shared = CachingGateway()
	
	private var transactions = Dictionary<Int, Transaction>()
	private var loadedMonths = [String]()
	
	private func makeString(fromDate date:Date) -> String {
		let components = Calendar.current.dateComponents(AppDelegate.unitsYM, from: date)
		return "\(components.year ?? 0)-\(components.month ?? 0)"
	}
	
	private init() {
		
	}
	
	var userName: String! {
		get {
			return RestGateway.shared.userName
		}
		set {
			RestGateway.shared.userName = newValue
		}
	}
	
	var fullName: String? {
		return RestGateway.shared.fullName
	}
	
	func clearCache() {
		self.transactions.removeAll()
		self.loadedMonths.removeAll()
	}
	
	var isLoggedIn: Bool {
		return RestGateway.shared.isLoggedIn
	}
	
	func login() {
		RestGateway.shared.login()
	}
	
	func logout() {
		RestGateway.shared.logout()
		clearCache()
	}
	
	func getTransaction(withID id: Int, callback: @escaping (Message) -> Void) {
		if let localT = transactions[id] {
			// Construct message to return transaction
			callback(TransactionMessage(localT))
		}
		else {
			RestGateway.shared.getTransaction(withID: id) {message in
				if let t = message.transaction {
					self.transactions[t.id] = t
				}
				callback(message)
			}
		}
	}
	
	func createTransaction(transaction: Transaction, callback: @escaping (Message) -> Void) {
		RestGateway.shared.createTransaction(transaction: transaction) {message in
			if let t = message.transaction {
				self.transactions[t.id] = t
				NotificationCenter.default.post(name: Notification.Name(rawValue: Notifications.DataUpdated.rawValue),
												object: self,
												userInfo: nil)
			}
			callback(message)
		}
	}
	
	func updateTransaction(transaction: Transaction, callback: @escaping (Message) -> Void) {
		RestGateway.shared.updateTransaction(transaction: transaction) {firstmessage in
			if let updatedID = firstmessage.updatedTransactionID {
				RestGateway.shared.getTransaction(withID: updatedID) { secondmessage in
					if let t = secondmessage.transaction {
						self.transactions[t.id] = t
						NotificationCenter.default.post(name: Notification.Name(rawValue: Notifications.DataUpdated.rawValue),
														object: self,
														userInfo: nil)
					}
					callback(secondmessage)
				}
			}
		}
	}
	
	func deleteTransaction(transaction: Transaction, callback: @escaping (Message) -> Void) {
		deleteTransaction(withID: transaction.id, callback: callback)
	}
	
	func deleteTransaction(withID id: Int, callback: @escaping (Message) -> Void) {
		RestGateway.shared.deleteTransaction(withID: id) { message in
			if message.code == 200 {
				self.transactions.removeValue(forKey: id)
			}
			callback(message)
		}
	}
	
	func getTransactions(forYear year: Int, month: Int, callback: @escaping (Message) -> Void) {
		let key = "\(year)-\(month)"
		if loadedMonths.contains(key) {
			let transactions = self.getCachedTransactions(forYear: year, month: month)
			let tMessage = TransactionsMessage(transactions)
			callback(tMessage)
		}
		else {
			RestGateway.shared.getTransactions(forYear: year, month: month) {[weak self] message in
				if let fetched = message.transactions {
					for t in fetched {
						self?.transactions[t.id] = t
					}
					self?.loadedMonths.append(key)
				}
				callback(message)
			}
		}
	}
	
	func getTransactions(forYear year: Int, month: Int, day: Int, callback: @escaping (Message) -> Void) {
		let key = "\(year)-\(month)"
		if loadedMonths.contains(key) {
			let transactions = self.getCachedTransactions(forYear: year, month: month, day: day)
			let tMessage = TransactionsMessage(transactions)
			callback(tMessage)
		}
		else {
			RestGateway.shared.getTransactions(forYear: year, month: month, day: day) { [weak self] message in
				if let fetched = message.transactions {
					for t in fetched {
						self?.transactions[t.id] = t
					}
					// DO NOT append to loadedMonths. We've not loaded all transactions
					// loadedMonths.append(key)
				}
			}
		}
	}

	func getTransactions(forYear year: Int, month: Int, day: Int, limitedTo tt: TransactionType?, callback: @escaping (Message) -> Void) {
		let key = "\(year)-\(month)"
		if loadedMonths.contains(key) {
			let transactions = self.getCachedTransactions(forYear: year, month: month).filter {$0.transactionType == tt}
			let tMessage = TransactionsMessage(transactions)
			callback(tMessage)
		}
		else {
			RestGateway.shared.getTransactions(forYear: year, month: month, day: -1, limitedTo: tt) { message in
				if let fetched = message.transactions {
					for t in fetched {
						self.transactions[t.id] = t
					}
					// DO NOT append to loadedMonths. We've not loaded all transactions
					// loadedMonths.append(key)
				}
				callback(message)
			}
		}
	}
	
	private func getCachedTransactions(forYear year: Int, month: Int) -> [Transaction] {
		var transactionsToReturn = [Transaction]()
		for (_, t) in self.transactions {
			let components = Calendar.current.dateComponents(AppDelegate.unitsYM, from: t.date)
			if components.year == year && components.month == month {
				transactionsToReturn.append(t)
			}
		}
		return transactionsToReturn
	}
	
	private func getCachedTransactions(forYear year: Int, month: Int, day: Int) -> [Transaction] {
		var transactionsToReturn = [Transaction]()
		for (_, t) in self.transactions {
			let components = Calendar.current.dateComponents(AppDelegate.unitsYMD, from: t.date)
			if components.year == year && components.month == month && components.day == day {
				transactionsToReturn.append(t)
			}
		}
		return transactionsToReturn
	}

	func getSearchResults(_ query: String, callback: @escaping (Message) -> Void) {
		RestGateway.shared.getSearchResults(query, callback: callback)
	}
	
	func getTransactionTypes(callback: @escaping (Message) -> Void) {
		RestGateway.shared.getTransactionTypes(callback: callback)
	}
	
	func getBalanceSummary(forYear year: Int, month: Int, callback: @escaping (Message) -> Void) {
		RestGateway.shared.getBalanceSummary(forYear: year, month: month, callback: callback)
	}
	
	func getCategorySummary(forYear year: Int, month: Int, callback: @escaping (Message) -> Void) {
		RestGateway.shared.getCategorySummary(forYear: year, month: month, callback: callback)
	}
	
	
}
