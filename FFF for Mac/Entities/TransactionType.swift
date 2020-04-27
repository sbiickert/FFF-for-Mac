//
//  TransactionType.swift
//  FFFMobile
//
//  Created by Simon Biickert on 2016-07-15.
//  Copyright © 2016 Simon Biickert. All rights reserved.
//

import AppKit

struct TransactionType: Equatable, Hashable, Codable, Identifiable {
	var id: Int
	var name: String
	var symbol: String
	var category: String
	
	var isExpense: Bool {
		return category == "EXPENSE"
	}
	
	static var defaultExpense: TransactionType {
		return transactionType(forCode: 6)! // Other
	}
	static var defaultIncome: TransactionType {
		return transactionType(forCode: 31)! // Other
	}

	static func transactionType(forCode code: Int) -> TransactionType? {
		let allTransactionTypes = transactionTypes
		
		for tt in allTransactionTypes {
			if tt.id == code {
				return tt
			}
		}
		return nil
	}
	
	private static var _transactionTypes = [TransactionType]()
	static var transactionTypes: [TransactionType] {
		get {
			if _transactionTypes.count == 0 {
				// Load some placeholder types. Will be replaced by web content.
				_transactionTypes = loadPlaceholderTransactionTypes()
			}
			return _transactionTypes
		}
		set (values) {
			_transactionTypes = values.sorted { $0.name < $1.name }
		}
	}
	
	static func transactionTypes(forExpense: Bool) -> [TransactionType] {
		return forExpense ? transactionTypesForExpense() : transactionTypesForIncome()
	}
	
	static func transactionTypesForExpense() -> [TransactionType] {
		let expenseTypes = transactionTypes.filter { $0.isExpense }
		return expenseTypes
	}
	
	static func transactionTypesForIncome() -> [TransactionType] {
		let incomeTypes = transactionTypes.filter { $0.isExpense == false }
		return incomeTypes
	}
	
	private static func loadPlaceholderTransactionTypes() -> [TransactionType] {
		var types = [TransactionType]()
		if let asset = NSDataAsset(name: "TransactionTypes", bundle: Bundle.main) {
			do {
				types = try JSONDecoder().decode([TransactionType].self, from: asset.data)
			}
			catch  let err {
				print("Err", err)
			}
		}
		return types
	}
}
