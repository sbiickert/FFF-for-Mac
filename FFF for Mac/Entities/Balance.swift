//
//  Balance.swift
//  FFFMobile
//
//  Created by Simon Biickert on 2016-07-16.
//  Copyright © 2016 Simon Biickert. All rights reserved.
//

import Foundation

struct Balance: Codable {
	var index:Int = 0
	var income:Double = 0.0
	var expense:Double = 0.0
	var diff:Double = 0.0
	
//	var difference: Double {
//		return income - expense
//	}
}

struct BalanceSummary: Codable {
	// Just keeping track of what the summary was for
	var year:Int = -1
	var month:Int = -1
	var day:Int = -1
	
	// Each Balance item has an index property, which is the y, m or d it represents.
	// Array indexes are not important
	var yearBalance: Balance?
	var monthBalances = [Balance]()
	var dayBalances = [Balance]()
	
	func balance(forMonth month:Int) -> Balance? {
		let filtered = monthBalances.filter {$0.index == month}
		return filtered.first
	}
	
	func balance(forDay day:Int) -> Balance? {
		let filtered = dayBalances.filter {$0.index == day}
		return filtered.first
	}
}
