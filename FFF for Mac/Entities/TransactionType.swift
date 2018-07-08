//
//  TransactionType.swift
//  FFFMobile
//
//  Created by Simon Biickert on 2016-07-15.
//  Copyright © 2016 Simon Biickert. All rights reserved.
//

import Cocoa

enum TransactionTypeKey: String {
	case ID = "id"
	case Name = "name"
	case Category = "transactionCategory"
	case Symbol = "symbol"
}

struct TransactionType: Equatable {
	var code: Int
	var description: String
	var emoji: String
	var isExpense: Bool
	
	init(dictionary: NSDictionary) {
		let tempID = Int(dictionary[TransactionTypeKey.ID.rawValue] as! String)
		code = tempID!
		description = dictionary[TransactionTypeKey.Name.rawValue] as! String
		emoji = dictionary[TransactionTypeKey.Symbol.rawValue] as! String
		if let category = dictionary[TransactionTypeKey.Category.rawValue] as? String {
			isExpense = category == "EXPENSE"
		}
		else { isExpense = false }
	}
	
	
	var dictionary: NSDictionary {
		let dict = NSMutableDictionary()
		
		dict[TransactionTypeKey.ID.rawValue] = String(self.code)
		dict[TransactionTypeKey.Name.rawValue] = self.description
		dict[TransactionTypeKey.Category.rawValue] = self.isExpense ? "EXPENSE" : "INCOME"
		dict[TransactionTypeKey.Symbol.rawValue] = self.emoji
		
		return dict
	}

	static func transactionType(forCode code: Int) -> TransactionType? {
		let allTransactionTypes = transactionTypes
		
		for tt in allTransactionTypes {
			if tt.code == code {
				return tt
			}
		}
		return nil
	}
	
	static var transactionTypes: [TransactionType] {
		get {
			var expenses = transactionTypesForExpense()
			let income = transactionTypesForIncome()
			expenses.append(contentsOf: income)
			return expenses
		}
	}
	
	static func transactionTypesForExpense() -> [TransactionType] {
		let defaults = UserDefaults.standard
		let defaultsTypes = defaults.array(forKey: DefaultsKey.ExpenseTypes.rawValue)
		let expenseTypes = TransactionType.arrayOfDefaultsToArrayOfTransactionTypes(defaultsTypes! as NSArray, areExpenses: true)
		
		return expenseTypes
	}
	
	static func transactionTypesForIncome() -> [TransactionType] {
		let defaults = UserDefaults.standard
		let defaultsTypes = defaults.array(forKey: DefaultsKey.IncomeTypes.rawValue)
		let incomeTypes = TransactionType.arrayOfDefaultsToArrayOfTransactionTypes(defaultsTypes! as NSArray, areExpenses: false)
		
		return incomeTypes
	}
	
	static func arrayOfDefaultsToArrayOfTransactionTypes(_ defaults: NSArray, areExpenses: Bool) -> [TransactionType] {
		var returnArray = [TransactionType]()
		for ao in defaults {
			let info = ao as! NSDictionary
			var tt = TransactionType(dictionary: info)
			tt.isExpense = areExpenses
			returnArray.append(tt)
		}
		return returnArray;
	}
}
