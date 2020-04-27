//
//  Category.swift
//  FFFMobile
//
//  Created by Simon Biickert on 2016-07-16.
//  Copyright © 2016 Simon Biickert. All rights reserved.
//

import Foundation

struct Category: Codable, Hashable {
	var amount: Float
	var percent: Float
	var tt: Int
	var ttName: String
	
	var isExpense: Bool {
		return TransactionType.transactionType(forCode: self.tt)?.isExpense ?? false
	}
}

struct CategorySummary:Codable {
	var year: Int = -1
	var month: Int = -1
	var categories = [Category]()
	
	var income: [Category] {
		return categories.filter { $0.isExpense == false }
	}
	
	var expenses: [Category] {
		return categories.filter { $0.isExpense == true }
	}
	
}
