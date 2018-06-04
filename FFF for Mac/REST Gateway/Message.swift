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
		else // if (messageInfo != nil)
		{
			self.isError = false;
			content = messageInfo as! NSDictionary
		}
		
		self.url = self.content[ResponseKey.Url.rawValue] as! String
		self.code = content[ResponseKey.Code.rawValue] as! Int
	}
    
    var errorInfo: NSDictionary? {
        get {
			if self.isError {
				return content
			}
			return nil
        }
    }
	
	private let createdTransactionIDRegEx = "created transaction (\\d+)"
	var createdTransactionID: Int? {
		get {
			let searchString = content[ResponseKey.Message.rawValue] as? String
			if let range = searchString?.range(of:createdTransactionIDRegEx,
											  options: .regularExpression) {
				let idString = Int(searchString![range])
				return idString
			}
			return nil
		}
	}
    
    var transaction: Transaction? {
        get {
			if let tDict = content[ResponseKey.Message.rawValue] as? NSDictionary {
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
