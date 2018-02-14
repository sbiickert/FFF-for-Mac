//
//  Balance.swift
//  FFFMobile
//
//  Created by Simon Biickert on 2016-07-16.
//  Copyright © 2016 Simon Biickert. All rights reserved.
//

import Foundation

enum BalanceKey: String {
	case Income = "income"
	case Expense = "expense"
}

struct Balance {
	var income: NSNumber
	var expense: NSNumber
	
	var difference: NSNumber {
		get {
			let diff = income.doubleValue - expense.doubleValue
			return NSNumber(value: diff)
		}
	}
	
	static var decimalFormatter: NumberFormatter?
	
	init() {
		self.income = NSNumber(value: 0)
		self.expense = NSNumber(value: 0)
	}
	
	init(dictionary: NSDictionary) {
		if Balance.decimalFormatter == nil {
			Balance.decimalFormatter = NumberFormatter()
			Balance.decimalFormatter?.numberStyle = NumberFormatter.Style.decimal
		}
		
		self.income = NSNumber(value: 0); self.expense = NSNumber(value: 0)
		
		let incomeValue = dictionary[BalanceKey.Income.rawValue]
		if let incomeStr = incomeValue as? String {
			self.income = Balance.decimalFormatter!.number(from: incomeStr)!
		}
		else if let incomeNum = incomeValue as? NSNumber {
			self.income = incomeNum
		}
		
		let expenseValue = dictionary[BalanceKey.Expense.rawValue]
		if let expenseStr = expenseValue as? String {
			self.expense = Balance.decimalFormatter!.number(from: expenseStr)!
		}
		else if let expenseNum = expenseValue as? NSNumber {
			self.expense = expenseNum
		}
	}
}

enum BalanceSummaryKey: String {
	case ForDay = "forDay"
	case ForMonth = "forMonth"
	case ForYear = "forYear"
	case Date = "date"
	case Day = "day"
	case Balance = "balance"
}

struct BalanceSummary {
	// Indexes 1 to 31, 0 is nil
	var dayBalances: [Balance?]
	
	// Indexes 1 to 12, 0 is nil
	var monthBalances: [Balance?]
	
	var yearBalance: Balance?
	
	init(dictionary: NSDictionary) {
		// The 'forDay' key contains an array, but days without a balance are skipped.
		let forDay = dictionary[BalanceSummaryKey.ForDay.rawValue] as! NSArray
		dayBalances = [Balance?]()
		dayBalances.append(nil) // index zero, not used

		var i = 1
		for dayObj in forDay {
			let dayInfo = dayObj as! NSDictionary
			// Determine which day this is for
			let dateInfo = dayInfo[BalanceSummaryKey.Date.rawValue] as! NSDictionary
			let dayOfMonth = (dateInfo[BalanceSummaryKey.Day.rawValue] as! NSNumber).intValue
			
			while i < dayOfMonth {
				dayBalances.append(Balance()) // zero balance
				i = i + 1
			}
			
			let balanceForDay = Balance(dictionary: dayInfo[BalanceSummaryKey.Balance.rawValue] as! NSDictionary)
			dayBalances.append(balanceForDay)
			i = i + 1
		}

		// The 'forMonth' key contains an array with 12 elements
		let forMonth = dictionary[BalanceSummaryKey.ForMonth.rawValue] as! NSArray
		monthBalances = [Balance?]()
		monthBalances.append(nil) // index zero, not used
		
		for monthObj in forMonth {
			let monthInfo = monthObj as! NSDictionary
			let balanceForMonth = Balance(dictionary: monthInfo)
			monthBalances.append(balanceForMonth)
		}
		
		// The 'forYear' key contains a dictionary.
		let forYear = dictionary[BalanceSummaryKey.ForYear.rawValue] as! NSDictionary
		yearBalance = Balance(dictionary: forYear)
	}
}
