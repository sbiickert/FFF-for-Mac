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

	init() {
		// When the user logs in
		NotificationCenter.default.publisher(for: .loginResponse)
			.sink { _ in
				self.requestMonthData()
				//self.requestDayData()
		}.store(in: &self.storage)
		
		// When the user logs out
		NotificationCenter.default.publisher(for: .logoutResponse)
			.sink { _ in
				//self.currentDayTransactions = [FFFTransaction]()
				self.currentMonthBalance = nil
				self.currentMonthCategories = nil
				self.currentMonthTransactions = [FFFTransaction]()
		}.store(in: &self.storage)
		
		// When the month changes (year and/or month)
		NotificationCenter.default.publisher(for: .currentMonthChanged)
			.sink { _ in
				self.requestMonthData()
				//self.requestDayData()
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
				//self.requestDayData()
		}.store(in: &self.storage)
		
		// When the user requests a refresh
		NotificationCenter.default.publisher(for: .refreshData)
			.sink { _ in
				self.willTriggerDataRefreshedNotification = true
				self.requestMonthData() // Will trigger .dataRefreshed when currentMonthTransactions loads
				//self.requestDayData()
		}.store(in: &self.storage)
	}
	
	private func requestMonthData() {
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
		}.store(in: &self.storage)

		let cReq = RestGateway.shared.createRequestGetCategorySummary(forYear: ymd.year, month: ymd.month)
		URLSession.shared.dataTaskPublisher(for: cReq)
			.map { $0.data }
			.replaceError(with: Data())
			.decode(type: CategorySummary.self, decoder: JSONDecoder())
			.replaceError(with: CategorySummary())
			.sink { cs in
				self.currentMonthCategories = (cs.year == -1) ? nil : cs
		}.store(in: &self.storage)

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
		}.store(in: &self.storage)
	}
	
//	private func requestDayData() {
//		// Request day transactions here
//		let ymd = self.currentDateComponents
//		let tReq = RestGateway.shared.createRequestGetTransactions(forYear: ymd.year, month: ymd.month, day: ymd.day)
//		URLSession.shared.dataTaskPublisher(for: tReq)
//			.map { $0.data }
//			.replaceError(with: Data())
//			.decode(type: [CodableTransaction].self, decoder: JSONDecoder())
//			.replaceError(with: [CodableTransaction]())
//			.map { ctArray in
//				ctArray.map { $0.transaction }
//			}
//			.sink { tArray in
//				self.currentDayTransactions = tArray
//		}.store(in: &self.storage)
//	}
	
	func createTransactions(_ createdTransactions: [FFFTransaction]) {
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
		
		let req = RestGateway.shared.createRequestCreateTransactions(transactions: createdTransactions)
		URLSession.shared.dataTaskPublisher(for: req)
			.map { $0.data }
			.replaceError(with: Data())
			.decode(type: [CodableTransaction].self, decoder: JSONDecoder())
			.replaceError(with: [CodableTransaction]())
			.sink { ct_list in
				NotificationCenter.default.post(name: .dataUpdated, object: nil)
			}.store(in: &self.storage)

	}
	
	func updateTransactions(_ updatedTransactions: [FFFTransaction]) {
		guard updatedTransactions.count > 0 else { return }
		
		// Replace the local copies with the edited
		for dirtyT in updatedTransactions {
			if let index = currentMonthTransactions.firstIndex(where: { $0.id == dirtyT.id }) {
				currentMonthTransactions[index] = dirtyT
			}
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
	
	func deleteTransactions(withIDs delIDs:[Int]) {
		guard delIDs.count > 0 else { return }
		
		// Remove from the local transaction store if their id is in delIDs
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
