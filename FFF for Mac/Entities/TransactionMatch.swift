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
	
	static func stringValue(_ value: MatchType) -> String {
		switch value {
		case .none:
			return "❗️ None"
		case .partial:
			return "❓ Partial"
		case .complete:
			return "✔️ Complete"
		}
	}
}

class TransactionMatch {
	private static let minScore:Float = 0.2
	private static let maxPossibleCount = 10
	
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
		if matchType == .complete {
			return
		}
		let score = bankTransaction.getMatchScore(with: t)
		if score > TransactionMatch.minScore && transactionInPossibles(t) == false {
			possibleMatches.append(MatchScore(score: score, transaction: t))
		}
		possibleMatches.sort { lhs, rhs in
			return lhs.score > rhs.score
		}
		if score == 1.0 {
			designateTransactionAsMatch(at: 0)
		}
		if possibleMatches.count > TransactionMatch.maxPossibleCount {
			possibleMatches.remove(at: possibleMatches.count-1)
		}
	}
	
	private func transactionInPossibles(_ t: Transaction) -> Bool {
		for possible in possibleMatches {
			if possible.transaction.id == t.id {
				return true
			}
		}
		return false
	}
	
	func removeFromPossibles(_ transaction:Transaction) {
		for (index, ms) in possibleMatches.enumerated() {
			if ms.transaction.id == transaction.id {
				possibleMatches.remove(at: index)
				break
			}
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
