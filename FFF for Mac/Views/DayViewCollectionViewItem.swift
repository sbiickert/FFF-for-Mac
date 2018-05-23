//
//  DayViewCollectionViewItem.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-02-24.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa

class DayViewCollectionViewItem: NSCollectionViewItem {
	@IBOutlet weak var dateLabel: NSTextField!
	@IBOutlet weak var incomeLabel: NSTextField!
	@IBOutlet weak var expenseLabel: NSTextField!
	
	var dayOfMonth = 13 {
		didSet {
			updateUI()
		}
	}
	
	var incomeAmount: Double = 0.0 {
		didSet {
			updateUI()
		}
	}
	var incomeNumber: NSNumber {
		get {
			return NSNumber(floatLiteral: incomeAmount)
		}
	}
	
	var expenseAmount: Double = 0.0 {
		didSet {
			updateUI()
		}
	}
	var expenseNumber: NSNumber {
		get {
			return NSNumber(floatLiteral: expenseAmount)
		}
	}
	
	private func updateUI() {
//		view.isHidden = dayOfMonth < 1
//		incomeLabel.isHidden = incomeAmount <= 0.0
//		expenseLabel.isHidden = expenseAmount <= 0.0
		dateLabel?.stringValue = "\(dayOfMonth)"
		incomeLabel?.stringValue = Transaction.currencyFormatter.string(from: incomeNumber)!
		expenseLabel?.stringValue = Transaction.currencyFormatter.string(from: expenseNumber)!
	}
	

    override func viewDidLoad() {
        super.viewDidLoad()
        updateUI()
		self.view.wantsLayer = true
		self.view.layer?.backgroundColor = NSColor.black.cgColor
    }
    
}
