//
//  MonthBalanceView.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-06-20.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa

class MonthBalanceView: NSView {
	@IBOutlet weak var incomeLabel: NSTextField!
	@IBOutlet weak var expenseLabel: NSTextField!
	@IBOutlet weak var balanceLabel: NSTextField!
	
	var income: Float = 0.0 {
		didSet {
			updateUI()
		}
	}
	private var incomeNumber: NSNumber {
		return NSNumber(value: income)
	}
	
	var expense: Float = 0.0 {
		didSet {
			updateUI()
		}
	}
	private var expenseNumber: NSNumber {
		return NSNumber(value: expense)
	}
	
	private var balanceNumber: NSNumber {
		let balance = income - expense
		return NSNumber(value: balance)
	}

	private lazy var currFormatter = NumberFormatter()
	private func updateUI() {
		if incomeLabel != nil {
			currFormatter.numberStyle = .currency
			
			incomeLabel.stringValue = currFormatter.string(from: incomeNumber) ?? ""
			expenseLabel.stringValue = currFormatter.string(from: expenseNumber) ?? ""
			balanceLabel.stringValue = currFormatter.string(from: balanceNumber) ?? ""
		}
	}
		
//    override func draw(_ dirtyRect: NSRect) {
//        super.draw(dirtyRect)
//
//        // Drawing code here.
//    }
	
}
