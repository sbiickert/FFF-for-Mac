//
//  GatewayUtil.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-06-29.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Foundation

enum DateArgOption: String {
	case Year = "Y"
	case YearMonth = "YM"
	case YearMonthDay = "YMD"
}

struct Token {
	static let lifespanInSeconds = 3000
	
	public init(token: String) {
		tokenString = token
		expires = Calendar.current.date(byAdding: .second, value: Token.lifespanInSeconds, to: Date())
	}
	
	let tokenString: String
	let expires: Date!
	
	var isExpired: Bool {
		return expires < Date()
	}
}


protocol Gateway {
	
	var userName: String! {get set}
	var fullName: String? {get}
	
	var isLoggedIn: Bool {get}
	func login()
	func logout()
	
	func getTransaction(withID id:Int, callback: @escaping (Message) -> Void)
	func createTransaction(transaction: Transaction, callback: @escaping (Message) -> Void)
	func updateTransaction(transaction: Transaction, callback: @escaping (Message) -> Void)
	func deleteTransaction(transaction: Transaction, callback: @escaping (Message) -> Void)
	func deleteTransaction(withID id:Int, callback: @escaping (Message) -> Void)
	func getTransactionSeries(withID id:String, callback: @escaping (Message) -> Void)
	func getTransactions(forYear year:Int, month:Int, callback: @escaping (Message) -> Void)
	func getTransactions(forYear year:Int, month:Int, day:Int,
						 callback: @escaping (Message) -> Void)
	func getTransactions(forYear year:Int, month:Int, day: Int, limitedTo tt:TransactionType?, callback: @escaping (Message) -> Void)
	func getSearchResults(_ query:String, callback: @escaping (Message) -> Void)
	func getTransactionTypes(callback: @escaping (Message) -> Void)
	func getBalanceSummary(forYear year:Int, month:Int, callback: @escaping (Message) -> Void)
	func getCategorySummary(forYear year:Int, month:Int, callback: @escaping (Message) -> Void)
}

