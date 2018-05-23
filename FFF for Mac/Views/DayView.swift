//
//  DayView.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-02-25.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa

class DayView: NSView {
	var dateLabel: NSTextField!
	var incomeLabel: NSTextField!
	var expenseLabel: NSTextField!
	
	required init?(coder decoder: NSCoder) {
		super.init(coder: decoder)
	}
	
	func initLabels() {
		let labels = getLabelsInView(view: self)
		dateLabel = labels[0]
		incomeLabel = labels[1]
		expenseLabel = labels[2]
	}
	
	private func getLabelsInView(view: NSView) -> [NSTextField] {
		var results = [NSTextField]()
		for subview in view.subviews as [NSView] {
			if let label = subview as? NSTextField {
				results += [label]
			} else {
				results += getLabelsInView(view: subview)
			}
		}
		return results
	}

	var dayOfMonth = -1 {
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
		self.isHidden = dayOfMonth < 1
		incomeLabel.isHidden = incomeAmount <= 0.0
		expenseLabel.isHidden = expenseAmount <= 0.0
		dateLabel?.stringValue = "\(dayOfMonth)"
		incomeLabel?.stringValue = Transaction.currencyFormatter.string(from: incomeNumber)!
		expenseLabel?.stringValue = Transaction.currencyFormatter.string(from: expenseNumber)!
	}
	
//    override func draw(_ dirtyRect: NSRect) {
//        super.draw(dirtyRect)
//
//        // Drawing code here.
//    }
	
}
