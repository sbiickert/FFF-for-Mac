//
//  TransactionMatch.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-06-15.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Foundation

struct MatchScore {
	let score: Float
	let transaction: Transaction
}

enum MatchType: Float {
	case none = 0.0
	case partial = 0.5
	case complete = 1.0  // Float values are just to support sorting
}

class TransactionMatch {
	var bankTransaction: BankTransaction!
	var matchedTransaction:Transaction?
	var possibleMatches = [MatchScore]()
	
	init(with bt:BankTransaction) {
		self.bankTransaction = bt
	}
	
	var matchType: MatchType {
		if matchedTransaction == nil {
			if possibleMatches.count == 0 {
				return .none
			}
			return .partial
		}
		return .complete
	}
	
	func addTransaction(_ t:Transaction) {
		let score = bankTransaction.getMatchScore(with: t)
		if score > 0.0 {
			possibleMatches.append(MatchScore(score: score, transaction: t))
		}
		possibleMatches.sort { lhs, rhs in
			return lhs.score < rhs.score
		}
	}
	
	func designateTransactionAsMatch(at index:Int) {
		if index < 0 || index >= possibleMatches.count {
			return
		}
		matchedTransaction = possibleMatches[index].transaction
		possibleMatches.removeAll()
	}
}
