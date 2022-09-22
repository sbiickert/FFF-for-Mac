//
//  DateView.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-07-02.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa

class DateView: NSControl {

	@IBOutlet weak var prevMonthButton: NSButton!
	@IBOutlet weak var monthLabel: NSTextField!
	@IBOutlet weak var nextMonthButton: NSButton!
	@IBOutlet weak var prevYearButton: NSButton!
	@IBOutlet weak var yearLabel: NSTextField!
	@IBOutlet weak var nextYearButton: NSButton!
	
	@IBAction func prevMonth(_ sender: Any) {
		date = Calendar.current.date(byAdding: .month, value: -1, to: date)!
		sendAction()
	}
	@IBAction func nextMonth(_ sender: Any) {
		date = Calendar.current.date(byAdding: .month, value: 1, to: date)!
		sendAction()
	}
	@IBAction func prevYear(_ sender: Any) {
		date = Calendar.current.date(byAdding: .year, value: -1, to: date)!
		sendAction()
	}
	@IBAction func nextYear(_ sender: Any) {
		date = Calendar.current.date(byAdding: .year, value: 1, to: date)!
		sendAction()
	}
	
	private func sendAction() {
		if let a = self.action {
			NSApp.sendAction(a, to: self.target, from: self)
		}
	}
	
	private var dateFormatter = DateFormatter()
	var date = Date() {
		didSet {
			updateUI()
		}
	}
	private var monthName: String {
		dateFormatter.dateFormat = "LLLL"
		return dateFormatter.string(from: date)
	}
	private var year:String {
		dateFormatter.dateFormat = "YYYY"
		return dateFormatter.string(from: date)
	}
	
	private func updateUI() {
		if monthLabel != nil {
			monthLabel.stringValue = monthName
			yearLabel.stringValue = year
		}
	}
}
