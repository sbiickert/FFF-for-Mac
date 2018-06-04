//
//  BrowseViewController.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-02-17.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa

class CalendarViewController: NSViewController {
	struct Values {
		static let insets = 8
		static let normalBackgroundColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
		static let selectedBackgroundColor = #colorLiteral(red: 0.9951301731, green: 1, blue: 0.7860673396, alpha: 1)
	}
	
	@IBOutlet weak var calendarView: NSView!
	private var grid = Grid(layout: Grid.Layout.dimensions(rowCount: 6, columnCount: 7))
	private var dayViews = [DayView]()
	
	private var monthBalance: BalanceSummary?
	
	private var app:AppDelegate {
		get {
			return NSApplication.shared.delegate as! AppDelegate
		}
	}
	
	static var monthFormatter: DateFormatter = {
		let monthFormat = DateFormatter.dateFormat(fromTemplate: "MMMMYYYY", options: 0, locale: Locale.current)
		var formatter = DateFormatter()
		formatter.dateFormat = monthFormat
		return formatter
	}()

	var currentDate:Date {
		get {
			return app.currentDate
		}
		set(value) {
			app.currentDate = value
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
			return firstComponents.weekday! - 1
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
	
	//MARK: View Controller
	
	override func viewDidLoad() {
        super.viewDidLoad()
		NotificationCenter.default.addObserver(self,
											   selector: #selector(loginNotificationReceived(_:)),
											   name: NSNotification.Name(rawValue: Notifications.LoginResponse.rawValue),
											   object: nil)
		NotificationCenter.default.addObserver(self,
											   selector: #selector(logoutNotificationReceived(_:)),
											   name: NSNotification.Name(rawValue: Notifications.LogoutResponse.rawValue),
											   object: nil)
		NotificationCenter.default.addObserver(self,
											   selector: #selector(currentDateChanged(_:)),
											   name: NSNotification.Name(rawValue: Notifications.CurrentDateChanged.rawValue),
											   object: nil)
		for _ in 0..<grid.cellCount {
			let dayView = DayView(frame:CGRect.zero)
			self.calendarView.addSubview(dayView)
			dayViews.append(dayView)
			let clickRecognizer = NSClickGestureRecognizer(target: self, action: #selector(dayClicked(_:)))
			dayView.addGestureRecognizer(clickRecognizer)
		}
	}
	
	override func viewWillAppear() {
		super.viewWillAppear()
		updateView()
	}
	
	override func viewDidLayout() {
		super.viewDidLayout()
		updateView()
	}
	
	private func updateView(forceUpdate force:Bool = false) {
		if updateGrid() || force {
			let components = app.currentDateComponents
			// Animate day views to grid
			for (index, dayView) in dayViews.enumerated() {
				let dayOfMonth = index - dayOfWeekOffsetForTheFirst + 1 // +1 because we don't start with day zero
				if dayOfMonth >= 1 && dayOfMonth <= numberOfDaysInCurrentMonth {
					dayView.dayOfMonth = dayOfMonth
					if dayOfMonth == components.day {
						dayView.backgroundColor = Values.selectedBackgroundColor
					}
					else {
						dayView.backgroundColor = Values.normalBackgroundColor
					}
					if let bal = monthBalance, let dayBal = bal.dayBalances[dayOfMonth] {
						dayView.expenseAmount = dayBal.expense.doubleValue
						dayView.incomeAmount = dayBal.income.doubleValue
					}
				}
				else {
					dayView.dayOfMonth = -1
					dayView.expenseAmount = 0.0
					dayView.incomeAmount = 0.0
				}
				if let frame = getFrame(for: dayView) {
					relocateDayView(dayView, to: frame)
				}
			}
		}
	}
	
	@discardableResult
	func updateGrid() -> Bool {
		var gridChanged = false
		if grid.frame != self.calendarView.bounds {
			grid.frame = self.calendarView.bounds
			gridChanged = true
		}
		return gridChanged
	}

	private func getFrame(for dayView:DayView) -> CGRect? {
		for (index, otherView) in dayViews.enumerated() {
			if dayView == otherView {
				let frame = grid[index]!
				let converted = calendarView.convert(frame, to: view)
				return converted
			}
		}
		return nil
	}
	
	private func relocateDayView(_ dayView: DayView, to frame:CGRect) {
		NSAnimationContext.runAnimationGroup({_ in
			NSAnimationContext.current.duration = 0.1
			dayView.animator().frame = frame
		}, completionHandler: {})
	}
	
	@IBAction func dayClicked(_ gestureRecognizer: NSClickGestureRecognizer) {
		if let dayView = gestureRecognizer.view as? DayView {
			app.setDayOfMonth(dayView.dayOfMonth)
		}
	}

	// MARK: Notifications
	
	@objc func loginNotificationReceived(_ notification: Notification) {
		requestSummaryForMonth(currentDate)
	}
	
	@objc func logoutNotificationReceived(_ notification: Notification) {
		monthBalance = nil
		DispatchQueue.main.async {
			self.updateView(forceUpdate: true)
		}
	}

	@objc func currentDateChanged(_ notification: Notification) {
		requestSummaryForMonth(app.currentDate)
	}

	func requestSummaryForMonth(_ date: Date) {
		let components = app.currentDateComponents
		Gateway.shared.getBalanceSummary(forYear: components.year, month: components.month) {message in
			self.monthBalance = message.balanceSummary
			DispatchQueue.main.async {
				self.updateView(forceUpdate: true)
			}
		}
	}

}


