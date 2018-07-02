//
//  BrowseViewController.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-02-17.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa

class CalendarViewController: FFFViewController {
	struct Values {
		static let insets = 8
		static let normalBackgroundColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
		static let selectedBackgroundColor = #colorLiteral(red: 0.9951301731, green: 1, blue: 0.7860673396, alpha: 1)
	}
	
	@IBOutlet weak var calendarView: NSView!
	private var grid = Grid(layout: Grid.Layout.dimensions(rowCount: 6, columnCount: 7))
	private var dayViews = [DayView]()
	private var monthBalance: BalanceSummary?

	@IBOutlet weak var sundayLabel: NSTextField!
	@IBOutlet weak var mondayLabel: NSTextField!
	@IBOutlet weak var tuesdayLabel: NSTextField!
	@IBOutlet weak var wednesdayLabel: NSTextField!
	@IBOutlet weak var thursdayLabel: NSTextField!
	@IBOutlet weak var fridayLabel: NSTextField!
	@IBOutlet weak var saturdayLabel: NSTextField!
	
	static var monthFormatter: DateFormatter = {
		let monthFormat = DateFormatter.dateFormat(fromTemplate: "MMMMYYYY", options: 0, locale: Locale.current)
		var formatter = DateFormatter()
		formatter.dateFormat = monthFormat
		return formatter
	}()
	
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
		for _ in 0..<grid.cellCount {
			let dayView = DayView(frame:CGRect.zero)
			self.calendarView.addSubview(dayView)
			dayViews.append(dayView)
			let clickRecognizer = NSClickGestureRecognizer(target: self, action: #selector(dayClicked(_:)))
			dayView.addGestureRecognizer(clickRecognizer)
		}
		repointCenteringConstraint(for: sundayLabel, to: dayViews[0])
		repointCenteringConstraint(for: mondayLabel, to: dayViews[1])
		repointCenteringConstraint(for: tuesdayLabel, to: dayViews[2])
		repointCenteringConstraint(for: wednesdayLabel, to: dayViews[3])
		repointCenteringConstraint(for: thursdayLabel, to: dayViews[4])
		repointCenteringConstraint(for: fridayLabel, to: dayViews[5])
		repointCenteringConstraint(for: saturdayLabel, to: dayViews[6])
		view.needsLayout = true
	}
	
	private func repointCenteringConstraint(for item:NSView, to target:NSView) {
		var remove = [NSLayoutConstraint]()
		var add = [NSLayoutConstraint]()
		
		let constraints = view.constraints.filter {$0.firstItem as! NSView == item && $0.firstAttribute == NSLayoutConstraint.Attribute.centerX}
		if let constraint = constraints.first {
			remove.append(constraint)
			add.append(NSLayoutConstraint(item: item, attribute: constraint.firstAttribute, relatedBy: constraint.relation, toItem: target, attribute: constraint.secondAttribute, multiplier: constraint.multiplier, constant: constraint.constant))
		}
		view.removeConstraints(remove)
		view.addConstraints(add)
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
				dayView.dayOfMonth = -1
				dayView.expenseAmount = 0.0
				dayView.incomeAmount = 0.0
				if dayOfMonth >= 1 && dayOfMonth <= numberOfDaysInCurrentMonth {
					dayView.dayOfMonth = dayOfMonth
					if dayOfMonth == components.day {
						dayView.backgroundColor = Values.selectedBackgroundColor
					}
					else {
						dayView.backgroundColor = Values.normalBackgroundColor
					}
					if let bal = monthBalance {
						if dayOfMonth < bal.dayBalances.count {
							if let dayBal = bal.dayBalances[dayOfMonth] {
								dayView.expenseAmount = dayBal.expense.doubleValue
								dayView.incomeAmount = dayBal.income.doubleValue
							}
						}
					}
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
	
	override func loginNotificationReceived(_ notification: Notification) {
		requestSummaryForMonth(currentDate)
	}
	
	override func logoutNotificationReceived(_ notification: Notification) {
		monthBalance = nil
		DispatchQueue.main.async {
			self.updateView(forceUpdate: true)
		}
	}

	override func currentDateChanged(_ notification: Notification) {
		requestSummaryForMonth(app.currentDate)
	}

	override func currentDayChanged(_ notification: Notification) {
		updateView(forceUpdate: true)
	}

	override func dataUpdated(_ notification: Notification) {
		requestSummaryForMonth(app.currentDate)
	}

	func requestSummaryForMonth(_ date: Date) {
		let components = app.currentDateComponents
		CachingGateway.shared.getBalanceSummary(forYear: components.year, month: components.month) {message in
			self.monthBalance = message.balanceSummary
			DispatchQueue.main.async {
				self.updateView(forceUpdate: true)
			}
		}
	}

}


