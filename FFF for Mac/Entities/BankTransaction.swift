//
//  BankTransaction.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-06-15.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Foundation

struct BankTransaction {
	static let unitsD:Set<Calendar.Component> = [.day]
	static let noEval = ["Transfer", "PAYMENT - THANK YOU / PAIEMENT - MERCI", "INTEREST PAYMENT", "WWW TFR", "WWW PMT", "BR TO BR", "LOAN PROCEEDS"]
	
	let id:Int
	let date: Date
	let desc1: String
	let desc2: String?
	let amount: Float  // Negative: withdrawal/expense
	
	var isExpense: Bool {
		return amount < 0.0
	}
	
	var description: String {
		if desc2 == nil {
			return desc1
		}
		return "\(desc1) - \(desc2!)"
	}
	
	var ignorable: Bool {
		for str in BankTransaction.noEval {
			if description.starts(with: str) {
				return true
			}
		}
		return false
	}

	func getMatchScore(with t:Transaction) -> Float {
		let interval = Calendar.current.dateComponents(BankTransaction.unitsD, from: date, to: t.date)
		
		let daysDiff = abs(interval.day!)
		var amountDiff:Float = abs(t.amount - amount)
		
		if let tt = t.transactionType {
			if tt.isExpense {
				// BankTransaction will be negative, FFF amount is positive
				amountDiff = abs(t.amount + amount)
			}
		}
		
		// Right date, right amount
		if daysDiff == 0 && amountDiff == 0.0 {
			return 1.0
		}
		
		// Right amount, day not right
		if amountDiff == 0 {
			// Reduce by 0.1 per day to a minimum of 0.0
			return max(0.0, 1.0 - (0.1 * Float(daysDiff)))
		}
		
		// Right date, amount not right
		if daysDiff == 0 {
			// Inverse of percentage difference
			return 1.0 - (amountDiff/t.amount)
		}
		
		// Both date and amount not right
		let daysScore = 1.0 - (amountDiff/t.amount)
		let amountScore = max(0.0, 1.0 - (0.1 * Float(daysDiff)))
		return daysScore * amountScore
	}

}
