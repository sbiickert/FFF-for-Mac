//
//  TransactionType.swift
//  FFFMobile
//
//  Created by Simon Biickert on 2016-07-15.
//  Copyright © 2016 Simon Biickert. All rights reserved.
//

import Cocoa

enum TransactionTypeKey: String {
	case ID = "id"
	case Name = "name"
	case Category = "transactionCategory"
}
enum Icons {
	static let cable = "📺"
	static let childcare = "🧒"
	static let clothing = "👗"
	static let computerRelated = "🖥"
	static let craftHobby = "🎨"
	static let eatingOut = "🍟"
	static let education = "🎓"
	static let entertainment = "📽"
	static let esriBenefit = "💊"
	static let esriSalary = "💰"
	static let fitness = "🚴🏻‍♀️"
	static let gift = "🎁"
	static let groceries = "🛒"
	static let homeImprovement = "🛠"
	static let insurance = "👨🏻‍💼"
	static let interest = "📈"
	static let internet = "🌎"
	static let medical = "🚑"
	static let mortgage = "🏡"
	static let other = "🤷‍♀️"
	static let petRelated = "🐈"
	static let rrspSavings = "👴🏻"
	static let tax = "💸"
	static let teachingSalary = "💰"
	static let telephone = "📞"
	static let transportationAuto = "🚗"
	static let transportationMC = "🏍"
	static let transportationOther = "🚉"
	static let travel = "✈️"
	static let tutoring = "👩‍🏫"
	static let utilities = "💡"
}

struct TransactionType {
	var code: Int
	var description: String
	var isExpense: Bool
	
	init(dictionary: NSDictionary) {
		let tempID = Int(dictionary[TransactionTypeKey.ID.rawValue] as! String)
		code = tempID!
		description = dictionary[TransactionTypeKey.Name.rawValue] as! String
		if let category = dictionary[TransactionTypeKey.Category.rawValue] as? String {
			isExpense = category == "EXPENSE"
		}
		else { isExpense = false }
	}
	
	private static let emojiForCode = [14: Icons.cable, 9: Icons.childcare, 12: Icons.clothing,
											17: Icons.computerRelated, 24: Icons.craftHobby, 2: Icons.eatingOut,
											23: Icons.education, 20: Icons.entertainment, 8: Icons.fitness,
											7: Icons.gift, 13: Icons.groceries, 11: Icons.homeImprovement,
											4: Icons.insurance, 25: Icons.internet, 18: Icons.medical,
											3: Icons.mortgage, 6: Icons.other, 10: Icons.petRelated,
											19: Icons.rrspSavings, 21: Icons.tax, 5: Icons.telephone,
											1: Icons.transportationAuto, 22: Icons.transportationMC, 16: Icons.transportationOther,
											39: Icons.travel, 15: Icons.utilities,
											34: Icons.esriBenefit, 33: Icons.esriSalary, 28: Icons.gift,
											30: Icons.interest, 31: Icons.other, 32: Icons.teachingSalary, 35: Icons.tutoring ]
	
	private static let assetNamesForCode = [14: "cable", 9: "childcare", 12: "clothing",
											17: "computer_related", 24: "craft_hobby", 2: "eating_out",
											23: "education", 20: "entertainment", 8: "fitness",
											7: "gift", 13: "groceries", 11: "home_improvement",
											4: "insurance", 25: "internet", 18: "medical",
											3: "mortgage", 6: "other", 10: "pet_related",
											19: "rrsp_savings", 21: "tax", 5: "telephone",
											1: "transportation_auto", 22: "transportation_mc", 16: "transportation_other",
											39: "travel", 15: "utilities",
											34: "esri_benefit", 33: "esri_salary", 28: "gift",
											30: "interest", 31: "other", 32: "teaching_salary", 35: "tutoring" ]
	var icon: NSImage {
		let assetName = TransactionType.assetNamesForCode[code] ?? "other"
		return NSImage(named: NSImage.Name(assetName))!
	}
	
	var emoji: String {
		return TransactionType.emojiForCode[code] ?? "🍄"
	}
	
	static func transactionType(forCode code: Int) -> TransactionType? {
		let allTransactionTypes = transactionTypes
		
		for tt in allTransactionTypes {
			if tt.code == code {
				return tt
			}
		}
		return nil
	}
	
	static var transactionTypes: [TransactionType] {
		get {
			var expenses = transactionTypesForExpense()
			let income = transactionTypesForIncome()
			expenses.append(contentsOf: income)
			return expenses
		}
	}
	
	static func transactionTypesForExpense() -> [TransactionType] {
		let defaults = UserDefaults.standard
		let defaultsTypes = defaults.array(forKey: DefaultsKey.ExpenseTypes.rawValue)
		let expenseTypes = TransactionType.arrayOfDefaultsToArrayOfTransactionTypes(defaultsTypes! as NSArray, areExpenses: true)
		
		return expenseTypes
	}
	
	static func transactionTypesForIncome() -> [TransactionType] {
		let defaults = UserDefaults.standard
		let defaultsTypes = defaults.array(forKey: DefaultsKey.IncomeTypes.rawValue)
		let incomeTypes = TransactionType.arrayOfDefaultsToArrayOfTransactionTypes(defaultsTypes! as NSArray, areExpenses: false)
		
		return incomeTypes
	}
	
	static func arrayOfDefaultsToArrayOfTransactionTypes(_ defaults: NSArray, areExpenses: Bool) -> [TransactionType] {
		var returnArray = [TransactionType]()
		for ao in defaults {
			let info = ao as! NSDictionary
			var tt = TransactionType(dictionary: info)
			tt.isExpense = areExpenses
			returnArray.append(tt)
		}
		return returnArray;
	}
}
