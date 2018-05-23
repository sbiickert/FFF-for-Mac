//
//  BrowseViewController.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-02-17.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa
enum CalendarVCNotificationNameKey: String {
	case CurrentMonthSummaryRetreived = "CalendarVCCurrentMonthSummaryRetrievedNotification"
}

class CalendarViewController: NSViewController {
	private var dayViews = [DayView]()
	@IBOutlet weak var monthLabel: NSTextField!
	@IBOutlet weak var previousMonthButton: NSButton!
	@IBOutlet weak var nextMonthButton: NSButton!
	
	@IBAction func previousMonth(_ sender: Any) {
		if let newDate = Calendar.current.date(byAdding: .month, value:-1, to: currentDate) {
			currentDate = newDate
		}
	}
	@IBAction func nextMonth(_ sender: Any) {
		if let newDate = Calendar.current.date(byAdding: .month, value:1, to: currentDate) {
			currentDate = newDate
		}
	}
	
	static var monthFormatter: DateFormatter = {
		let monthFormat = DateFormatter.dateFormat(fromTemplate: "MMMMYYYY", options: 0, locale: Locale.current)
		var formatter = DateFormatter()
		formatter.dateFormat = monthFormat
		return formatter
	}()

	var currentDate = Date() {
		didSet {
			// Set up the days in the calendar
			for i in 0..<dayViews.count {
				dayViews[i].dayOfMonth = 0
				dayViews[i].incomeAmount = 0
				dayViews[i].expenseAmount = 0
			}

			let numberOfDaysInMonth = numberOfDaysInCurrentMonth
			for i in 1...numberOfDaysInMonth {
				if let dayView = dayViewFor(dayOfMonth: i) {
					dayView.dayOfMonth = i
				}
			}
			
			// Change the header text
			monthLabel.stringValue = CalendarViewController.monthFormatter.string(from: currentDate)
			
			// Request balance
			requestSummaryForMonth(currentDate)
		}
	}
	
	private var dayOfWeekOffsetForTheFirst: Int {
		get {
			var components = Calendar.current.dateComponents(in: TimeZone.current, from: currentDate)
			components.day = 1 // Need the first of the month
			let firstOfTheMonth = Calendar.current.date(from: components)!
			let firstComponents = Calendar.current.dateComponents(in: TimeZone.current, from: firstOfTheMonth)
			// 1=Sunday, 2=Monday, 3=Tuesday, 4=Wednesday, 5=Thursday, 6=Friday, 7=Saturday
			// 1=January
			return firstComponents.weekday! - 2
		}
	}
	
	private func dayViewFor(dayOfMonth day:Int) -> DayView? {
		let offset = dayOfWeekOffsetForTheFirst
		let index = day + offset
		return dayViews[index]
	}
	
	private var numberOfDaysInCurrentMonth: Int {
		get {
			// Calculate start and end of the current year (or year with `.year`):
			let interval = Calendar.current.dateInterval(of: .month, for: currentDate)!
			
			// Compute difference in days:
			let days = Calendar.current.dateComponents([.day], from: interval.start, to: interval.end).day!
			return days
		}
	}
	
	override func viewDidLoad() {
        super.viewDidLoad()
		let nCenter = NotificationCenter.default
		nCenter.addObserver(self,
							selector: #selector(loginNotificationReceived(_:)),
							name: NSNotification.Name(rawValue: Notifications.LoginResponse.rawValue),
							object: nil)
		nCenter.addObserver(self,
							selector: #selector(currentMonthSummaryNotificationReceived(_:)),
							name: NSNotification.Name(rawValue: CalendarVCNotificationNameKey.CurrentMonthSummaryRetreived.rawValue),
							object: nil)


	}
	
	override func viewWillAppear() {
		super.viewWillAppear()
		configureCalendarView()
		currentDate = Date()
	}
	
	private func configureCalendarView() {
		// This is a big assumption that the views in the storyboard are in order
		// It seems like it is a valid assumption for the moment
		let views = getDaysInView(view: view)
		
		for view in views {
			view.wantsLayer = true
			view.layer?.backgroundColor = NSColor.controlShadowColor.cgColor
			view.layer?.cornerRadius = 8.0
		}
		
		dayViews = views
	}
	
	private func getDaysInView(view: NSView) -> [DayView] {
		var results = [DayView]()
		for subview in view.subviews as [NSView] {
			if let dayView = subview as? DayView {
				dayView.initLabels()
				results += [dayView]
			} else {
				results += getDaysInView(view: subview)
			}
		}
		return results
	}
	
	@objc func loginNotificationReceived(_ notification: Notification) {
		if let userInfo = (notification as NSNotification).userInfo {
			if (userInfo[ResponseKey.Success.rawValue] as! NSNumber).boolValue {
				requestSummaryForMonth(currentDate)
			}
		}
	}
	
	@objc func currentMonthSummaryNotificationReceived(_ notification: Notification) {
		if let userInfo = (notification as NSNotification).userInfo {
			if (userInfo[ResponseKey.Success.rawValue] as! NSNumber).boolValue {
				let message = userInfo[ResponseKey.Message.rawValue] as! Message

				let summaryDict = message.content[ResponseKey.BalanceSummary.rawValue] as! NSDictionary
				let balanceSummary = BalanceSummary(dictionary: summaryDict)

				for i in 1...numberOfDaysInCurrentMonth {
					if let dayBalance = balanceSummary.dayBalances[i] {
						let dayView = dayViewFor(dayOfMonth: i)
						dayView?.incomeAmount = dayBalance.income.doubleValue
						dayView?.expenseAmount = dayBalance.expense.doubleValue
					}
				}
			}
		}
	}

	func requestSummaryForMonth(_ date: Date) {
		let dateArg = Gateway.urlArgumentForDate(date, withOption: DateArgOption.YearMonth)
		let userInfo:[String: AnyObject]? = [ResponseKey.ResourcePath.rawValue: String(format:"balance%@", dateArg) as AnyObject,
											 ResponseKey.ResourceNotificationName.rawValue: CalendarVCNotificationNameKey.CurrentMonthSummaryRetreived.rawValue as AnyObject]
		NotificationCenter.default.post(name: Notification.Name(rawValue: Notifications.ResourceRequest.rawValue),
										object: self,
										userInfo: userInfo)
	}

}


