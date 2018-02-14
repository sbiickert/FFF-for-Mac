//
//  Category.swift
//  FFFMobile
//
//  Created by Simon Biickert on 2016-07-16.
//  Copyright © 2016 Simon Biickert. All rights reserved.
//

import Foundation

enum CategoryKey: String {
	case Amount = "amount"
	case Percent = "percent"
	case TypeID = "typeID"
	case IsExpense = "isExpense"
	case TypeName = "typeName"
}

struct Category {
	var amount: Float
	var isExpense: Bool
	var percent: Float
	var transactionTypeID: Int
	var transactionTypeName: String
	
	init(dictionary: NSDictionary) {
		var tempNumber = dictionary[CategoryKey.Amount.rawValue] as! NSNumber
		amount = tempNumber.floatValue
		tempNumber = dictionary[CategoryKey.Percent.rawValue] as! NSNumber
		percent = tempNumber.floatValue
		tempNumber = dictionary[CategoryKey.TypeID.rawValue] as! NSNumber
		transactionTypeID = tempNumber.intValue
		
		isExpense = dictionary[CategoryKey.IsExpense.rawValue] as! String == "true"
		transactionTypeName = dictionary[CategoryKey.TypeName.rawValue] as! String
	}
}

enum CategorySummaryKey: String {
	case Items = "items"
}

struct CategorySummary {
	var expenses: [Category]
	var income: [Category]
	
	init(dictionary: NSDictionary) {
		// The 'items' key contains an array
		let items = dictionary[CategorySummaryKey.Items.rawValue] as! NSArray
		
		expenses = [Category]()
		income = [Category]()
		
		for categoryObj in items {
			let categoryInfo = categoryObj as! NSDictionary
			let category = Category(dictionary: categoryInfo)
			if category.isExpense {
				expenses.append(category)
			}
			else {
				income.append(category)
			}
		}
	}
}
