//
//  FFFTransactionSeries.swift
//  FFF ∞
//
//  Created by Simon Biickert on 2019-12-05.
//  Copyright © 2019 ii Softwerks. All rights reserved.
//

import Foundation
import Combine

protocol TransactionSeries {
	var repeatInfo: RepeatInfo {get set}
	var transactions: [FFFTransaction] {get set}
	var seriesID: String? {get set}
	var templateTransaction: FFFTransaction?  {get set}
	var isValid: Bool {get}
	var isClean: Bool {get}
	var isExpense: Bool {get}
	var isSeries: Bool {get}
	var transactionType: TransactionType  {get set}
	var date: Date {get set}
	var description: String {get set}
	var amountString: String  {get set}
	var transactionTypeLabel: String {get}
	var garbage: [FFFTransaction] {get}
	var needToLoadSeriesTransactions: Bool {get}
	
	func loadExistingSeriesTransactions( callback: @escaping ((Bool) -> Void))
	func generateTransactionsInSeries()
	func prepareForDeletion()
}

class NormalTransactionSeries : TransactionSeries {
	var repeatInfo = RepeatInfo.None
	var transactions = [FFFTransaction]() {
		didSet {
			if let _ = templateTransaction {
				let sid = seriesID
				for i in 0..<transactions.count {
					if transactions[i].isLocked == false {
						transactions[i].seriesID = sid
					}
				}
				if repeatInfo == RepeatInfo.None {
					let r = analyzeRepeatPattern()
					if repeatInfo != r {
						repeatInfo = r
					}
				}
			}
		}
	}

	var seriesID: String? {
		get {
			if let t = transactions.first {
				return t.seriesID
			}
			return nil
		}
		set {
			for i in 0..<transactions.count {
				if transactions[i].isLocked == false {
					transactions[i].seriesID = newValue
				}
			}
		}
	}
	
	var templateTransaction: FFFTransaction? {
		get {
			return transactions.first { $0.isLocked == false }
		}
		set {
			guard let t = newValue else {
				return
			}
			transactions.insert(t, at: 0)
			if seriesID != nil {
				needToLoadSeriesTransactions = true
			}
		}
	}
	
	var isValid: Bool {
		if let t = templateTransaction {
			return t.isValid
		}
		return false
	}
	
	var isClean: Bool {
		if let t = templateTransaction {
			return t.modificationStatus == .clean && garbage.count == 0
		}
		return false
	}
	
	var isExpense: Bool {
		if let t = templateTransaction {
			return t.isExpense
		}
		return true
	}
	
	var isSeries: Bool {
		return transactions.count > 1
	}

	var transactionType: TransactionType {
		get {
			if templateTransaction != nil {
				return templateTransaction!.transactionType
			}
			return TransactionType.defaultExpense
		}
		set {
			for i in 0..<transactions.count {
				if transactions[i].isLocked == false {
					transactions[i].transactionType = newValue
				}
			}
		}
	}
	
	var date: Date {
		get {
			if let t = templateTransaction {
				return t.date
			}
			return Date()
		}
		set {
			if let template = templateTransaction {
				for (i, t) in transactions.enumerated() {
					if t == template {
						transactions[i].date = newValue
					}
				}
			}
		}
	}
	
	var description: String {
		get {
			if let t = templateTransaction {
				return t.description
			}
			return ""
		}
		set {
			for i in 0..<transactions.count {
				if transactions[i].isLocked == false {
					transactions[i].description = newValue
				}
			}
		}
	}
	
	var amountString: String {
		get {
			if let t = templateTransaction {
				return t.amountString
			}
			return ""
		}
		set {
			for i in 0..<transactions.count {
				transactions[i].amountString = newValue
			}
		}
	}

	var transactionTypeLabel: String {
		if let t = templateTransaction {
			return t.transactionTypeLabel
		}
		return ""
	}
	
	private func analyzeRepeatPattern() -> RepeatInfo {
		let repeatType = probableSeriesRepeatType
		let repeatDuration = probableSeriesRepeatDuration
		
		return RepeatInfo(type: repeatType, duration: repeatDuration)
	}
	
	private var probableSeriesRepeatType: RepeatType {
		// Look at the existing transactions in the series and guess the repeat
		var r = RepeatType.No
		if let gap = averageGapInSeries() {
			if gap > 0.5 && gap < 1.5 {
				r = .Daily
			}
			else if gap > 6.5 && gap < 7.5 {
				r = .Weekly
			}
			else if gap > 13.5 && gap < 14.5 {
				r = .Biweekly
			}
			else if gap > 27.5 && gap < 31.5 {
				r = .Monthly
			}
			else {
				r = .Yes
			}
			print("Gap is \(gap) days.")
		}
		print("Repeat is \(r)")
		return r
	}
	
	private var probableSeriesRepeatDuration: RepeatDuration {
		if isSeries {
			// Check for end of year first
			let psrType = probableSeriesRepeatType
			let lastDate = transactions.last!.date
			let lastDateYMD = Calendar.current.dateComponents(AppDelegate.unitsYMD, from: lastDate)
			
			switch psrType {
			case .Daily:
				if lastDateYMD.month! == 12 && lastDateYMD.day! == 31 {
					return .YearEnd
				}
			case .Weekly:
				if lastDateYMD.month! == 12 && lastDateYMD.day! > (31-7) {
					return .YearEnd
				}
			case .Biweekly:
				if lastDateYMD.month! == 12 && lastDateYMD.day! > (31-14) {
					return .YearEnd
				}
			case .Monthly:
				if lastDateYMD.month! == 12 {
					return .YearEnd
				}
			default:
				break
			}
			
			// Try based on number of days from start to finish
			let timeIntervalSeconds = transactions.first!.date.distance(to: lastDate)
			let timeIntervalDays = abs(timeIntervalSeconds / 60 / 60 / 24)
			if timeIntervalDays < 31 {
				return .MonthEnd
			}
			if timeIntervalDays < 93 {
				return .ThreeMonths
			}
			if timeIntervalDays < 186 {
				return .SixMonths
			}
		}
		return .None
	}
	
	private var storage = Set<AnyCancellable>()
	private(set) var needToLoadSeriesTransactions = false
	func loadExistingSeriesTransactions( callback: @escaping ((Bool) -> Void)) {
		let req = RestGateway.shared.createRequestGetTransactionSeries(withID: self.seriesID!)
		URLSession.shared.dataTaskPublisher(for: req)
			.tryMap { output in
				guard let response = output.response as? HTTPURLResponse, response.statusCode == 200 else {
					print("Err loading transaction series")
					callback(false)
					return Data()
				}
				return output.data
			}
			.decode(type: [CodableTransaction].self, decoder: JSONDecoder())
			.replaceError(with: [CodableTransaction]())
			.map { ctArray in
				ctArray.map { $0.transaction }
			}
			.sink { tArray in
				var loaded = tArray
				for (i, t) in loaded.enumerated() {
					if t.date < self.date {
						loaded[i].modificationStatus = .locked
					}
				}
				self.transactions = loaded.sorted { $0.date < $1.date }
				callback(true)
		}.store(in: &self.storage)

		// Now that we have called this once, flag it
		needToLoadSeriesTransactions = false
	}
	
	private(set) var garbage = [FFFTransaction]()
	func generateTransactionsInSeries() {
 		var generated = [FFFTransaction]()
		
		// Take any transactions in transactions that are in the DB (are not new)
		// and put them in the garbage for deletion (Not the template transaction...)
		guard var template = templateTransaction else {
			return
		}
		garbage.append(contentsOf: transactions.filter { t in
			t.isNew == false && t.isLocked == false && t.id != template.id
		})
		print("Garbage contains \(garbage.map {$0.id})")
		
		generated.append(contentsOf: transactions.filter { t in
			t.isLocked // Transactions in the past are locked
		})

		// Get the dates for the series transactions
		// Calc end date from the first in series, not the template (first x might be in the past and locked)
		let endDate = repeatEndDate(for: transactions.first!.date, until: self.repeatInfo.duration)
		let dates = repeatDates(for: template.date, withFrequency: self.repeatInfo.type, endingOn: endDate)
		
		if dates.count + generated.count > 0 {
			template.seriesID = self.seriesID ?? UUID().uuidString
		}
		else {
			template.seriesID = nil
		}
		
		generated.append(template)
		for d in dates {
			var t = FFFTransaction()
			t.amount = template.amount
			t.date = d
			t.description = template.description
			t.transactionType = template.transactionType
			t.seriesID = template.seriesID
			generated.append(t)
		}
		
		self.transactions = generated
	}
	
	func prepareForDeletion() {
		print("Preparing to delete transaction series")
		garbage.append(contentsOf: transactions.filter { t in
			t.isNew == false && t.isLocked == false
		})
		print("Garbage contains \(garbage.map {$0.id})")
		transactions = [FFFTransaction]()
	}
	
	private func repeatEndDate(for date:Date, until:RepeatDuration) -> Date {
		var endDate:Date!
		switch until {
		case .None, .Unknown:
			return date
		case .MonthEnd:
			endDate = Calendar.current.date(byAdding: .month, value: 1, to: date)!
		case .ThreeMonths:
			endDate = Calendar.current.date(byAdding: .month, value: 3, to: date)!
		case .SixMonths:
			endDate = Calendar.current.date(byAdding: .month, value: 6, to: date)!
		case .YearEnd:
			let dateComponents = Calendar.current.dateComponents(AppDelegate.unitsYM, from: date)
			let monthsToFollowingJanuary = 13 - dateComponents.month! // e.g. 13 - (may05) = 8 -> May + 8 months = next Jan
			endDate = Calendar.current.date(byAdding: .month, value: monthsToFollowingJanuary, to: date)!
		}
		// Find the last day of the month by going to the first, then subtracting one day
		var components = Calendar.current.dateComponents(AppDelegate.unitsYMD, from: endDate)
		components.day = 1
		endDate = Calendar.current.date(from: components)!
		endDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate)
		return endDate
	}

	private func repeatDates(for date:Date, withFrequency freq: RepeatType, endingOn endDate:Date) -> [Date] {
		var dates = [Date]()
		
		var component:Calendar.Component = .month
		var offset = 1
		
		switch freq {
		case .Daily:
			component = .day
		case .Weekly:
			component = .weekOfYear
		case .Biweekly:
			component = .weekOfYear
			offset = 2
		case .Monthly:
			component = .month
		default:
			return dates
		}
		
		var count = 1
		var seriesDate = Calendar.current.date(byAdding: component, value: offset * count, to: date)!
		while seriesDate <= endDate {
			if seriesDate >= self.date {
				dates.append(seriesDate)
			}
			count += 1
			seriesDate = Calendar.current.date(byAdding: component, value: offset * count, to: date)!
		}
		return dates
	}

	private func averageGapInSeries() -> Double? {
		if isSeries && transactions.count > 1 {
			let sortedT = transactions.sorted {$0.date < $1.date}
			let timeIntervalSeconds = sortedT.first!.date.distance(to: sortedT.last!.date)
			let timeIntervalDays = abs(timeIntervalSeconds / 60 / 60 / 24)
			return Double(timeIntervalDays) / Double(transactions.count-1)
		}
		return nil
	}
}

class IncomeExpenseTransactionSeries: TransactionSeries {
	var needToLoadSeriesTransactions = false
	
	init(templateTransaction t: FFFTransaction) {
		pair.primary = t
		pair.secondary = t
		generateTransactionsInSeries()
	}
	
	var repeatInfo = RepeatInfo.None
	
	private var pair: (primary: FFFTransaction, secondary: FFFTransaction)
	var transactions: [FFFTransaction] {
		get {
			return [pair.primary, pair.secondary]
		}
		set {
			if newValue.count > 0 {
				templateTransaction = newValue.first
			}
		}
	}
	
	var seriesID: String? {
		get {
			return nil
		}
		set {} // no-op
	}
	
	var templateTransaction: FFFTransaction? {
		get {
			return pair.primary
		}
		set {
			guard let t = newValue else { return }
			pair.primary = t
			generateTransactionsInSeries()
		}
	}
	
	var isValid: Bool {
		return pair.primary.isValid && pair.secondary.isValid
	}
	
	var isClean: Bool {
		return pair.primary.modificationStatus == .clean && garbage.count == 0
	}
	
	var isExpense: Bool {
		return pair.primary.isExpense
	}
	
	var isSeries: Bool {
		return true
	}
	
	var transactionType: TransactionType {
		get {
			return pair.primary.transactionType
		}
		set {
			pair.primary.transactionType = newValue
			if pair.primary.isExpense {
				pair.secondary.transactionType = TransactionType.defaultIncome
			}
			else {
				pair.secondary.transactionType = TransactionType.defaultExpense
			}
		}
	}
	
	var date: Date {
		get {
			return pair.primary.date
		}
		set {
			pair.primary.date = newValue
			pair.secondary.date = newValue
		}
	}
	
	var description: String {
		get {
			return pair.primary.description
		}
		set {
			pair.primary.description = newValue
			pair.secondary.description = newValue
		}
	}
	
	var amountString: String {
		get {
			return pair.primary.amountString
		}
		set {
			pair.primary.amountString = newValue
			pair.secondary.amountString = newValue
		}
	}
	
	var transactionTypeLabel: String {
		return pair.primary.transactionTypeLabel
	}
	
	func loadExistingSeriesTransactions(callback: @escaping ((Bool) -> Void)) {
		callback(true)
	}
	
	var garbage = [FFFTransaction]()
	func generateTransactionsInSeries() {
		// Create the secondary based on the primary
		let secondaryTT = pair.primary.isExpense ? TransactionType.defaultIncome : TransactionType.defaultExpense
		pair.secondary = FFFTransaction(id: -1,
										amount: pair.primary.amount,
										transactionType: secondaryTT,
										description: pair.primary.description,
										date: pair.primary.date,
										seriesID: pair.primary.seriesID,
										modificationStatus: .dirty)
	}
	
	func prepareForDeletion() {
		return
	}
}

struct RepeatInfo: Equatable {
	let type: RepeatType
	let duration: RepeatDuration
	
	static let None = RepeatInfo(type: .No, duration: .None)
}

// MARK: Handling repeating transactions
enum RepeatType : String, CaseIterable {
	case No
	case Yes
	case Daily
	case Weekly
	case Biweekly
	case Monthly
}

enum RepeatDuration : String, CaseIterable {
	case None = ""
	case Unknown = "Unknown"
	case MonthEnd = "To the end of the month"
	case ThreeMonths = "Three months"
	case SixMonths = "Six months"
	case YearEnd = "To the end of the year"
}
