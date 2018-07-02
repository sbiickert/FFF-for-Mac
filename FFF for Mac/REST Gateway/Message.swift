//
//  Message.swift
//  FFFMobile
//
//  Created by Simon Biickert on 2016-07-15.
//  Copyright © 2016 Simon Biickert. All rights reserved.
//

import Foundation

class Message: NSObject {
	var content: NSDictionary
	var url: String
	var isError: Bool
	var code: Int
	
	init(dictionary: NSDictionary) {
		// Is this an error? Has key "message": NO. Has key "error": YES
		let errorInfo = dictionary.object(forKey: ResponseKey.Error.rawValue)
		let messageInfo = dictionary.object(forKey: ResponseKey.Message.rawValue)
		
		if (errorInfo != nil)
		{
			self.isError = true
			content = errorInfo as! NSDictionary
		}
		else if (messageInfo != nil)
		{
			self.isError = false;
			content = messageInfo as! NSDictionary
		}
		else {
			self.isError = true
			content = NSDictionary()
		}
		
		self.url = self.content[ResponseKey.Url.rawValue] as? String ?? ""
		self.code = content[ResponseKey.Code.rawValue] as? Int ?? 500
	}
    
    var errorInfo: NSDictionary? {
        get {
			if self.isError {
				return content
			}
			return nil
        }
    }
	
	private let transactionIDRegEx = try! NSRegularExpression(pattern: "\\d+", options: .caseInsensitive)
	
	private let createdPrefix = "created transaction"
	var createdTransactionID: Int? {
		get {
			if let searchString = content[ResponseKey.Message.rawValue] as? String {
				if searchString.starts(with: createdPrefix) {
					let results = transactionIDRegEx.matches(in: searchString, range: NSRange(searchString.startIndex..., in: searchString))
					
					let matches = results.map { String(searchString[Range($0.range, in: searchString)!]) }
					if let idString = matches.first {
						return Int(idString)
					}
				}
			}
			return nil
		}
	}
	
	private let updatedPrefix = "updated transaction"
	var updatedTransactionID: Int? {
		get {
			if let searchString = content[ResponseKey.Message.rawValue] as? String {
				if searchString.starts(with: updatedPrefix) {
					let results = transactionIDRegEx.matches(in: searchString, range: NSRange(searchString.startIndex..., in: searchString))
					
					let matches = results.map { String(searchString[Range($0.range, in: searchString)!]) }
					if let idString = matches.first {
						return Int(idString)
					}
				}
			}
			return nil
		}
	}
	
	private let deletedPrefix = "deleted transaction"
	var deletedTransactionID: Int? {
		get {
			if let searchString = content[ResponseKey.Message.rawValue] as? String {
				if searchString.starts(with: deletedPrefix) {
					let results = transactionIDRegEx.matches(in: searchString, range: NSRange(searchString.startIndex..., in: searchString))
					
					let matches = results.map { String(searchString[Range($0.range, in: searchString)!]) }
					if let idString = matches.first {
						return Int(idString)
					}
				}
			}
			return nil
		}
	}
	
	var didModifyTransaction: Bool {
		return createdTransactionID != nil || updatedTransactionID != nil || deletedTransactionID != nil
	}

    var transaction: Transaction? {
        get {
			if let tDict = content[ResponseKey.Transaction.rawValue] as? NSDictionary {
            	return Transaction(dictionary: tDict)
			}
			return nil
        }
    }
    
    var transactions: [Transaction]? {
        get {
			if let transactionsArr = content[ResponseKey.Transactions.rawValue] as? NSArray {
				var transactions = [Transaction]()
				
				for obj in transactionsArr {
					let tDict = obj as! NSDictionary
					let transaction = Transaction(dictionary: tDict)
					transactions.append(transaction)
				}
				return transactions
			}
			return nil
        }
    }
    
    var transactionTypes: (income: [TransactionType], expense: [TransactionType])? {
        get {
			if let eTypeArray = content[ResponseKey.ExpenseTypes.rawValue] as? NSArray,
				let iTypeArray = content[ResponseKey.IncomeTypes.rawValue] as? NSArray {
				
				var eTypes = [TransactionType]()
				var iTypes = [TransactionType]()

				for obj in eTypeArray {
					let ttDict = obj as! NSDictionary
					let transactionType = TransactionType(dictionary: ttDict)
					eTypes.append(transactionType)
				}

				for obj in iTypeArray {
					let ttDict = obj as! NSDictionary
					let transactionType = TransactionType(dictionary: ttDict)
					iTypes.append(transactionType)
				}
				
				return (income: iTypes, expense: eTypes)
			}
			return nil
        }
    }
    
    var balanceSummary: BalanceSummary? {
        get {
			if let balDict = content[ResponseKey.BalanceSummary.rawValue] as? NSDictionary {
				return BalanceSummary(dictionary: balDict)
			}
			return nil
        }
    }
    
    var categorySummary: CategorySummary? {
        get {
			if let catDict = content[ResponseKey.BalanceSummary.rawValue] as? NSDictionary {
				return CategorySummary(dictionary: catDict)
			}
			return nil
        }
    }
}

class TransactionMessage: Message {
	private var _transaction: Transaction
	
	override var transaction: Transaction? {
		return _transaction
	}
	
	init(_ transaction: Transaction) {
		self._transaction = transaction
		super.init(dictionary: NSDictionary())
	}
}

class TransactionsMessage: Message {
	private var _transactions: [Transaction]
	
	override var transactions: [Transaction]? {
		return self._transactions
	}
	
	init(_ transactions: [Transaction]) {
		self._transactions = transactions
		super.init(dictionary: NSDictionary())
	}
}
