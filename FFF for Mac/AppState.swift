//
//  AppState.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2020-04-18.
//  Copyright © 2020 ii Softwerks. All rights reserved.
//

import Foundation
import Combine

class AppState {
	private var storage = Set<AnyCancellable>()
	var loginDelegate: LoginPresenterDelegate?

	// MARK: Init creates all of the combine notification listeners
	
	init() {
		// When the user logs in
		NotificationCenter.default.publisher(for: .loginResponse)
			.sink { _ in
				self.requestMonthData()
		}.store(in: &self.storage)
		
		// When the user logs out
		NotificationCenter.default.publisher(for: .logoutResponse)
			.sink { _ in
				self.currentMonthBalance = nil
				self.currentMonthCategories = nil
				self.currentMonthTransactions = [FFFTransaction]()
		}.store(in: &self.storage)
		
		// When the month changes (year and/or month)
		NotificationCenter.default.publisher(for: .currentMonthChanged)
			.sink { _ in
				self.requestMonthData()
		}.store(in: &self.storage)
		
		// When just the day of month changes
		NotificationCenter.default.publisher(for: .currentDayChanged)
			.sink { _ in
				self.selectCurrentDayTransactions()
		}.store(in: &self.storage)
		
		// When we are notified that data has changed
		NotificationCenter.default.publisher(for: .dataUpdated)
			.sink { _ in
				self.requestMonthData()
		}.store(in: &self.storage)
		
		// When the user requests a refresh
		NotificationCenter.default.publisher(for: .refreshData)
			.sink { _ in
				self.willTriggerDataRefreshedNotification = true
				self.requestMonthData() // Will trigger .dataRefreshed when currentMonthTransactions loads
		}.store(in: &self.storage)
	}
	
	// MARK: Requests data for the current month
	private var cancellableRequests = Set<AnyCancellable>()
	
	private func requestMonthData() {
		// If there is an outstanding set of requests for month data, cancel them.
		for cancellableRequest in cancellableRequests {
			cancellableRequest.cancel()
		}
		self.cancellableRequests.removeAll()
		
		// Request month bal, cat, transactions here
		let ymd = self.currentDateComponents
		let bReq = RestGateway.shared.createRequestGetBalanceSummary(forYear: ymd.year, month: ymd.month)
		URLSession.shared.dataTaskPublisher(for: bReq)
			.tryMap { output in
				guard let response = output.response as? HTTPURLResponse, response.statusCode == 200 else {
					self.loginDelegate?.showLogin()
					return Data()
				}
				return output.data
			}
			.decode(type: BalanceSummary.self, decoder: JSONDecoder())
			.replaceError(with: BalanceSummary())
			.sink { bs in
				self.currentMonthBalance = (bs.year == -1) ? nil : bs
		}.store(in: &self.cancellableRequests)

		let cReq = RestGateway.shared.createRequestGetCategorySummary(forYear: ymd.year, month: ymd.month)
		URLSession.shared.dataTaskPublisher(for: cReq)
			.map { $0.data }
			.replaceError(with: Data())
			.decode(type: CategorySummary.self, decoder: JSONDecoder())
			.replaceError(with: CategorySummary())
			.sink { cs in
				self.currentMonthCategories = (cs.year == -1) ? nil : cs
		}.store(in: &self.cancellableRequests)

		// Request current month transactions
		let tReq = RestGateway.shared.createRequestGetTransactions(forYear: ymd.year, month: ymd.month)
		URLSession.shared.dataTaskPublisher(for: tReq)
			.map { $0.data }
			.replaceError(with: Data())
			.decode(type: [CodableTransaction].self, decoder: JSONDecoder())
			.replaceError(with: [CodableTransaction]())
			.map { ctArray in
				ctArray.map { $0.transaction }
			}
			.sink { tArray in
				self.currentMonthTransactions = tArray
		}.store(in: &self.cancellableRequests)
	}
	
	// MARK: all edits go through these functions
	
	func createTransactions(_ createdTransactions: [FFFTransaction]) {
		// External calls have to register for undo
		createTransactions(createdTransactions, registerForUndo: true)
	}

	private func createTransactions(_ createdTransactions: [FFFTransaction], registerForUndo: Bool) {
		// Internal calls might be from an undo/redo, don't want to register them as edits in that case
		guard createdTransactions.count > 0 else { return }
		
		// Insert the new transactions locally
		for dirtyT in createdTransactions {
			if let index = currentMonthTransactions.lastIndex(where: { $0.date <= dirtyT.date }) {
				currentMonthTransactions.insert(dirtyT, at: index + 1)
			}
			else {
				currentMonthTransactions.append(dirtyT)
			}
		}
		
		// Used by CheckerViewController
		NotificationCenter.default.post(name: .transactionsCreated,
										object: self,
										userInfo: ["t": createdTransactions])
		
		enum HTTPError: LocalizedError {
			case statusCode
		}

		let req = RestGateway.shared.createRequestCreateTransactions(transactions: createdTransactions)
		URLSession.shared.dataTaskPublisher(for: req)
			.tryMap { output in
				guard let response = output.response as? HTTPURLResponse, response.statusCode == 201 else {
					throw HTTPError.statusCode
				}
				return output.data
			}
			.decode(type: [CodableTransaction].self, decoder: JSONDecoder())
			.replaceError(with: [CodableTransaction]())
			.sink { ct_list in
				// Store created transactions in undo stack
				let tList = ct_list.map { $0.transaction }
				if registerForUndo {
					self.pushUndo(Undoable(action: .create, original: [FFFTransaction](), result: tList))
				}
				else {
					// This was an undo/redo operation. Find the equivalent deleted transactions in the archive
					for fffT in tList {
						for archivedT in self.archiveOfDeletedTransactions.reversed() {
							if fffT.equalForTemplate(with: archivedT) {
								self.mappingOldIdsToNewIds[archivedT.id] = fffT.id
								break
							}
						}
					}
				}
				// Send notification
				NotificationCenter.default.post(name: .dataUpdated, object: nil)
			}.store(in: &self.storage)

	}
	
	func updateTransactions(_ updatedTransactions: [FFFTransaction]) {
		// External calls have to register for undo
		updateTransactions(updatedTransactions, registerForUndo: true)
	}
	
	private func updateTransactions(_ updatedTransactions: [FFFTransaction], registerForUndo: Bool) {
		// Internal calls might be from an undo/redo, don't want to register them as edits in that case
		guard updatedTransactions.count > 0 else { return }
		
		// Replace the local copies with the edited,
		// keeping the originals for undo
		var originals = [FFFTransaction]()
		for dirtyT in updatedTransactions {
			if let index = currentMonthTransactions.firstIndex(where: { $0.id == dirtyT.id }) {
				originals.append(currentMonthTransactions[index])
				currentMonthTransactions[index] = dirtyT
			}
		}
		
		// Store the originals for undo
		if registerForUndo {
			pushUndo(Undoable(action: .update, original: originals, result: updatedTransactions))
		}

		let req = RestGateway.shared.createRequestUpdateTransactions(transactions: updatedTransactions)
		URLSession.shared.dataTaskPublisher(for: req)
			.map { $0.data }
			.replaceError(with: Data())
			.decode(type: CodableOpResult.self, decoder: JSONDecoder())
			.replaceError(with: CodableOpResult(message: "", ids: []))
			.sink { cor in
				NotificationCenter.default.post(name: .dataUpdated, object: nil)
			}.store(in: &self.storage)
	}
	
	func deleteTransactions(_ deletedTransactions:[FFFTransaction]) {
		// External calls have to register for undo
		deleteTransactions(deletedTransactions, registerForUndo: true)
	}
	
	private func deleteTransactions(_ deletedTransactions:[FFFTransaction], registerForUndo: Bool) {
		// Internal calls might be from an undo/redo, don't want to register them as edits in that case
		guard deletedTransactions.count > 0 else { return }
		
		// Store the transactions for undo
		var realDeletedTransactions = [FFFTransaction]()
		if registerForUndo {
			realDeletedTransactions = deletedTransactions
			pushUndo(Undoable(action: .delete, original: deletedTransactions, result: [FFFTransaction]()))
		}
		else {
			// This is an Undo/Redo. Possible that the UndoManager has an old copy with the wrong ID.
			// We need to see if these ids are old, and if so find the right ids so as to delete the current copies.
			for var fffT in deletedTransactions {
				fffT.id = self.findNewestIDForPreviouslyDeletedTransaction(fffT)
				realDeletedTransactions.append(fffT)
			}
		}
		
		// Any time transactions are deleted, keep a copy just in case the delete is undone
		// And we need to line up the created (undo) feature with the deleted feature
		archiveOfDeletedTransactions.append(contentsOf: realDeletedTransactions)
		
		// Remove from the local transaction store if their id is in delIDs
		let delIDs = realDeletedTransactions.map { $0.id }
		currentMonthTransactions = currentMonthTransactions.filter { delIDs.contains($0.id) == false }

		let req = RestGateway.shared.createRequestDeleteTransactions(withIDs: delIDs)
		URLSession.shared.dataTaskPublisher(for: req)
			.map { $0.data }
			.replaceError(with: Data())
			.decode(type: CodableOpResult.self, decoder: JSONDecoder())
			.replaceError(with: CodableOpResult(message: "", ids: []))
			.sink { cor in
				NotificationCenter.default.post(name: .dataUpdated, object: nil)
			}.store(in: &self.storage)
	}
	
	// MARK: Undo and Redo Support
	
	var undoManager: UndoManager?
	
	/*
	*  Trying to solve a problem:
	*  If an Undo or Redo operation deletes 1..N transactions, the inverse operation
	*  creates transactions with different ids. Then the inverse-inverse operation will
	*  try to delete the transactions with the original ids, not the new ones.
	*  This map is meant to allow tracing of old ids to new ids so that later operations
	*  will be able to substitute them.
	*/
	private var archiveOfDeletedTransactions = [FFFTransaction]()
	private var mappingOldIdsToNewIds = Dictionary<Int, Int>()
	private func findNewestIDForPreviouslyDeletedTransaction(_ transaction: FFFTransaction) -> Int {
		var searchID = transaction.id
		// If an undo / redo happened multiple times, keep searching
		while mappingOldIdsToNewIds.keys.contains(searchID) {
			searchID = mappingOldIdsToNewIds[searchID]!
		}
		return searchID
	}
	
	private func pushUndo(_ value: Undoable) {
		print("pushUndo \(value.description)\nOriginal: \(value.original)\nResult:\(value.result)")
		self.undoManager?.registerUndo(withTarget: self) { selfTarget in
			switch value.action {
			case .create:
				print("Undoing created transactions")
				print("\(value.result) -> []")
				selfTarget.deleteTransactions(value.result, registerForUndo: false)
			case .update:
				print("Undoing updated transactions")
				print("\(value.result) -> \(value.original)")
				selfTarget.updateTransactions(value.original, registerForUndo: false)
			case .delete:
				print("Undoing deleted transactions")
				print("[] -> \(value.original)")
				// This will create transactions with different ids
				selfTarget.createTransactions(value.original, registerForUndo: false)
			}
			selfTarget.pushRedo(value)
		}
		self.undoManager?.setActionName(value.description)
	}
	
	private func pushRedo(_ value: Undoable) {
		print("pushRedo \(value.description)\nOriginal: \(value.original)\nResult:\(value.result)")
		self.undoManager?.registerUndo(withTarget: self) { selfTarget in
			switch value.action {
			case .create:
				print("Redoing created transactions")
				print("[] -> \(value.result)")
				// This will create transactions with different ids
				selfTarget.createTransactions(value.result, registerForUndo: false)
			case .update:
				print("Redoing updated transactions")
				print("\(value.original) -> \(value.result)")
				selfTarget.updateTransactions(value.result, registerForUndo: false)
			case .delete:
				print("Redoing deleted transactions")
				print("\(value.original) -> []")
				selfTarget.deleteTransactions(value.original, registerForUndo: false)
			}
			selfTarget.pushUndo(value)
		}
		self.undoManager?.setActionName(value.description)
	}

	// MARK: Date Management
	
	var currentDate = Date() {
		didSet {
			let oldComponents = Calendar.current.dateComponents(AppDelegate.unitsYMD, from: oldValue)
			let newComponents = Calendar.current.dateComponents(AppDelegate.unitsYMD, from: currentDate)

			if oldComponents.year! == newComponents.year! && oldComponents.month! == newComponents.month! {
				NotificationCenter.default.post(name: .currentDayChanged, object: self)
			}
			else {
				NotificationCenter.default.post(name: .currentMonthChanged, object: self)
			}
		}
	}
	
	var currentDateComponents: (year:Int, month:Int, day:Int) {
		get {
			let components = Calendar.current.dateComponents(AppDelegate.unitsYMD, from: currentDate)
			return (year:components.year!, month:components.month!, day:components.day!)
		}
	}
	
	func setDayOfMonth(_ day:Int) {
		var components = Calendar.current.dateComponents(AppDelegate.unitsYMD, from: currentDate)
		components.setValue(day, for: .day)
		if let newDate = Calendar.current.date(from: components) {
			currentDate = newDate
		}
	}

	// MARK: Properties trigger notifications when set
	
	private var willTriggerDataRefreshedNotification = false
	private var currentMonthTransactions = [FFFTransaction]() {
		didSet {
			NotificationCenter.default.post(name: .stateChange_MonthlyTransactions,
											object: self, userInfo: ["value": currentMonthTransactions])
			self.selectCurrentDayTransactions()
			if willTriggerDataRefreshedNotification {
				willTriggerDataRefreshedNotification = false
				NotificationCenter.default.post(name: .dataRefreshed, object: self)
			}
		}
	}
	
	private func selectCurrentDayTransactions() {
		// Gets a subset of the month transactions for the current day
		let ymd = self.currentDateComponents
		currentDayTransactions = currentMonthTransactions.filter { $0.dayOfMonth == ymd.day }
	}
	
	private var currentDayTransactions = [FFFTransaction]() {
		didSet {
			NotificationCenter.default.post(name: .stateChange_DailyTransactions,
											object: self, userInfo: ["value": currentDayTransactions])
		}
	}

	private var currentMonthBalance: BalanceSummary? {
		didSet {
			NotificationCenter.default.post(name: .stateChange_MonthlyBalance,
											object: self, userInfo: ["value": currentMonthBalance ?? BalanceSummary()])
		}
	}
	
	private var currentMonthCategories: CategorySummary? {
		didSet {
			NotificationCenter.default.post(name: .stateChange_MonthlyCategories,
											object: self, userInfo: ["value": currentMonthCategories ?? CategorySummary()])
		}
	}
}

struct Undoable {
	enum Action {
		case create
		case update
		case delete
	}
	
	let action: Action
	let original: [FFFTransaction]
	let result: [FFFTransaction]
	
	var count: Int {
		return max(original.count, result.count)
	}
	
	var description: String {
		var verb = ""
		switch action {
		case .create:
			verb = "Create"
		case .update:
			verb = "Update"
		case .delete:
			verb = "Delete"
		}
		return "\(verb) \(self.count == 1 ? "Transaction" : "Transactions")"
	}
}
