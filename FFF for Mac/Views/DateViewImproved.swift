//
//  DateViewImproved.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2020-04-27.
//  Copyright © 2020 ii Softwerks. All rights reserved.
//

import Cocoa

class DateViewImproved: NSControl {
	
	private enum SegmentIndex: Int {
		case previousYear = 0
		case previousMonth = 1
		case current = 2
		case nextMonth = 3
		case nextYear = 4
	}
	
	@IBOutlet weak var buttonBar: NSSegmentedControl!
	
	private var selectedSegment: SegmentIndex?
	@IBAction func buttonClick(_ sender: NSSegmentedControl) {
		// Fires twice: once on mouse down and once on mouse up
		if sender.selectedSegment >= 0 {
			// Mouse down: track the selected segment
			self.selectedSegment = SegmentIndex(rawValue: sender.selectedSegment)
			if let index = self.selectedSegment {
				// Change date
				switch index {
				case .previousYear:
					date = Calendar.current.date(byAdding: .year, value: -1, to: date)!
				case .previousMonth:
					date = Calendar.current.date(byAdding: .month, value: -1, to: date)!
				case .nextMonth:
					date = Calendar.current.date(byAdding: .month, value: 1, to: date)!
				case .nextYear:
					date = Calendar.current.date(byAdding: .year, value: 1, to: date)!
				case .current:
					// Go to today
					date = Date()
				}
				sendAction()
			}
			self.selectedSegment = nil
		}
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
		if buttonBar != nil {
			buttonBar.setLabel("\(monthName) \(year)", forSegment: 2)
		}
	}

}
