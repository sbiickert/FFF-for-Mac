//
//  Transaction.swift
//  FFFMobile
//
//  Created by Simon Biickert on 2016-07-15.
//  Copyright © 2016 Simon Biickert. All rights reserved.
//

import Foundation

enum ModificationStatus: String {
	case clean, dirty, deleted, locked
}

struct FFFTransaction: Identifiable {
	static var currencyFormatter: NumberFormatter = {
		var formatter = NumberFormatter()
		formatter.formatterBehavior = NumberFormatter.Behavior.behavior10_4
		formatter.numberStyle = NumberFormatter.Style.currency
		return formatter
	}()
	private static var amountEditingFormatter: NumberFormatter = {
		var formatter = NumberFormatter()
		formatter.minimumFractionDigits = 2
		formatter.maximumFractionDigits = 2
		formatter.minimumIntegerDigits = 1
		return formatter
	}()

	static func createSeriesID() -> String {
		return UUID().uuidString
	}
	
	static let seriesTag = "🔁" //"➿"
	static let unsavedSymbol = "⏳"
	static let lockedSymbol = "🔒"
	
	public init() {}
	public init(id: Int,
				amount: Float,
				transactionType: TransactionType,
				description: String,
				date: Date,
				seriesID: String?,
				modificationStatus: ModificationStatus) {
		self.id = id
		self.amount = amount
		self.transactionType = transactionType
		self.description = description
		self.date = date
		self.seriesID = (seriesID != nil && seriesID!.isEmpty) ? nil : seriesID
		self.modificationStatus = modificationStatus
	}
	
	var id: Int = 0

	var amount: Float = 0.0 {
		didSet {
			if isLocked {
				print("Cannot set amount if the transaction is locked")
				amount = oldValue
			}
			else {
				modificationStatus = .dirty
			}
		}
	}

	// this is a workaround because I can't figure out how to get SwiftUI to edit
	// a float value directly
	private var _amountString: String? = nil
	var amountString: String {
		get {
			return _amountString ?? FFFTransaction.amountEditingFormatter.string(from: NSNumber(value: self.amount)) ?? ""
		}
		set {
			if (modificationStatus != .locked) {
				_amountString = newValue
				if let number = Float(newValue) {
					self.amount = number
				}
				else {
					self.amount = 0.0
				}
			}
		}
	}

	
	var transactionType = TransactionType.defaultExpense{
		didSet {
			if isLocked {
				print("Cannot set transactionType if the transaction is locked")
				transactionType = oldValue
			}
			else {
				modificationStatus = .dirty
			}
		}
	}

	var description: String = "" {
		didSet {
			if isLocked {
				print("Cannot set description if the transaction is locked")
				description = oldValue
			}
			else {
				modificationStatus = .dirty
			}
		}
	}
	
	var date: Date = Date(){
		didSet {
			if isLocked {
				print("Cannot set date if the transaction is locked")
				date = oldValue
			}
			else {
				modificationStatus = .dirty
			}
		}
	}
	
	var modificationStatus: ModificationStatus = .clean {
		didSet {
			print("Set modification status of transaction \(id) to \(modificationStatus)")
		}
	}
	
	var isExpense: Bool {
		get {
			return transactionType.isExpense
		}
		set {
			if newValue == true && transactionType.isExpense == false {
				transactionType = TransactionType.defaultExpense
			}
			else if newValue == false &&  transactionType.isExpense {
				transactionType = TransactionType.defaultIncome
			}
		}
	}
	var isNew: Bool {
		return id <= 0
	}
	var isValid: Bool {
		// All amounts must be positive
		return amount >= 0.0
	}
	var isLocked: Bool {
		return modificationStatus == .locked
	}
	
	private static let unitsD: Set<Calendar.Component> = [.day]
	var dayOfMonth: Int {
		let components = Calendar.current.dateComponents(FFFTransaction.unitsD, from: date)
		return components.day!
	}
	
	var transactionTypeLabel: String {
		var label = self.transactionType.name
		if self.seriesID != nil {
			label = FFFTransaction.seriesTag + " " + label
		}
		return label
	}
	
	// MARK: Handling repeating transactions
	var seriesID: String? {
		didSet {
			if isLocked {
				print("Cannot set seriesID if the transaction is locked")
				seriesID = oldValue
			}
			else {
				if seriesID != nil && seriesID!.isEmpty {
					seriesID = nil
				}
				modificationStatus = .dirty
			}
		}
	}
	
	var isSeries: Bool {
		get {
			return seriesID != nil
		}
		set {
			if newValue == true && seriesID == nil {
				seriesID = UUID().uuidString
			}
			else if newValue == false && seriesID != nil {
				seriesID = nil
			}
		}
	}
}

// MARK: Equatable
extension FFFTransaction: Equatable {
	static func == (lhs: FFFTransaction, rhs: FFFTransaction) -> Bool {
		let amountsEqual = round(lhs.amount * 100) == round(rhs.amount * 100)
		return
			lhs.id == rhs.id &&
			lhs.date == rhs.date &&
			lhs.description == rhs.description &&
			lhs.seriesID == rhs.seriesID &&
			lhs.transactionType == rhs.transactionType &&
			amountsEqual
	}
	
	static func != (lhs: FFFTransaction, rhs: FFFTransaction) -> Bool {
		return !(lhs == rhs)
	}
	
	func equalForTemplate(with other:FFFTransaction) -> Bool {
		return self.amount == other.amount &&
			self.description == other.description &&
			self.transactionType == other.transactionType
	}
}

extension FFFTransaction: CustomDebugStringConvertible  {
	var debugDescription: String {
		return "[\(isExpense ? "E":"I")] \(transactionType.symbol)-\(id) \(FFFTransaction.currencyFormatter.string(from: NSNumber(value: amount)) ?? "-9999") '\(description)'"
	}
}
