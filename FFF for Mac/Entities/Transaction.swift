//
//  Transaction.swift
//  FFFMobile
//
//  Created by Simon Biickert on 2016-07-15.
//  Copyright © 2016 Simon Biickert. All rights reserved.
//

import Foundation

enum TransactionKey: String {
	case ID = "id"
	case Amount = "amount"
	case TransactionType = "type"
	case Description = "description"
	case User = "user"
	case Date = "transactionDate"
}

enum ModificationStatus {
	case clean, dirty, deleted
}

class TransactionWrapper :NSObject {
	var transaction: Transaction?
	
	init(transaction: Transaction) {
		self.transaction = transaction
	}
}

struct Transaction {
	static var currencyFormatter: NumberFormatter = {
		var formatter = NumberFormatter()
		formatter.formatterBehavior = NumberFormatter.Behavior.behavior10_4
		formatter.numberStyle = NumberFormatter.Style.currency
		return formatter
	}()
	
	var id: Int = 0
	var amount: Float = 0.0
	var transactionType: TransactionType?
	var description: String?
	var date: Date = Date()
	var modificationStatus: ModificationStatus = .clean
	var isNew: Bool = true
	
	var debugDescription: String {
		get {
			let units: Set<Calendar.Component> = [.day, .month, .year]
			let components = Calendar.current.dateComponents(units, from: self.date)
			
			let formattedAmount = Transaction.currencyFormatter.string(from: NSNumber(value: amount))!
			let year = NSNumber(value: components.year!)
			let month = NSNumber(value: components.month!)
			let day = NSNumber(value: components.day!)
			
			return String(format: "FFFTransaction #%ld %@ %@ on %@-%@-%@",
			              arguments: [id,
							formattedAmount,
							transactionType == nil ? "No TT" : transactionType!.description,
							year, month, day])
		}
	}
	
	init(dictionary: NSDictionary? = nil) {
		if let dict = dictionary {
			// The ID is returned as an integer string, Amount as decimal string, Date as date string
			let tempID = Int(dict[TransactionKey.ID.rawValue] as! String)
			self.id = tempID!
			let tempAmount = Float(dict[TransactionKey.Amount.rawValue] as! String)
			self.amount = tempAmount!
			let dateString = dict[TransactionKey.Date.rawValue] as! String
			self.date = DataFormatter.dateFromFFFDateString(dateString)!
			self.description = dict[TransactionKey.Description.rawValue] as? String
			self.isNew = false
			
			let tempTTDict = dict[TransactionKey.TransactionType.rawValue] as! NSDictionary
			self.transactionType = TransactionType(dictionary: tempTTDict)
		}
	}
	
}
