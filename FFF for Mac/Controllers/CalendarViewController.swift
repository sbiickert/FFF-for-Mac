//
//  BrowseViewController.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-02-17.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa
import Combine

class CalendarViewController: FFFViewController {
	struct Values {
		static let insets = 8
		static let selectedBackgroundColorName = "currentDayBackgroundColor"
	}
	
	@IBOutlet weak var calendarView: NSView!
	private var grid = Grid(layout: Grid.Layout.dimensions(rowCount: 6, columnCount: 7))
	private var dayViews = [DayView]()
	private var storage = Set<AnyCancellable>()

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
		let index = day + offset - 1
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
		
		NotificationCenter.default.publisher(for: .currentMonthChanged)
			.receive(on: DispatchQueue.main)
			.sink { _ in
				print("CalendarViewController received currentMonthChanged")
				self.clearViewContent()
				self.updateView(forceUpdate: true)
		}.store(in: &self.storage)
		
		NotificationCenter.default.publisher(for: .currentDayChanged)
			.receive(on: DispatchQueue.main)
			.sink { _ in
				self.updateView(forceUpdate: true)
		}.store(in: &self.storage)
		
		NotificationCenter.default.publisher(for: .stateChange_MonthlyBalance)
			.compactMap { $0.userInfo?["value"] as? BalanceSummary }
			.receive(on: DispatchQueue.main)
			.sink { bs in
				print("CalendarViewController received stateChange_MonthlyBalance")
				self.updateViewBalances(with: bs)
		}.store(in: &self.storage)
		
		NotificationCenter.default.publisher(for: .stateChange_MonthlyTransactions)
			.compactMap { $0.userInfo?["value"] as? [FFFTransaction] }
			.receive(on: DispatchQueue.main)
			.sink { transactions in
				print("CalendarViewController received stateChange_MonthlyTransactions")
				self.updateViewTransactions(with: transactions)
		}.store(in: &self.storage)
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
			let ymd = app.currentDateComponents
			// Animate day views to grid
			for (index, dayView) in dayViews.enumerated() {
				let dayOfMonth = index - dayOfWeekOffsetForTheFirst + 1 // +1 because we don't start with day zero
				dayView.dayOfMonth = -1
				if dayOfMonth >= 1 && dayOfMonth <= numberOfDaysInCurrentMonth {
					dayView.dayOfMonth = dayOfMonth
					if dayOfMonth == ymd.day {
						dayView.backgroundColor = NSColor(named: NSColor.Name("currentDayBackgroundColor")) ?? NSColor.purple
					}
					else {
						dayView.backgroundColor = NSColor.controlBackgroundColor
					}
				}
				if let frame = getFrame(for: dayView) {
					relocateDayView(dayView, to: frame)
				}
			}
		}
	}
	
	private func clearViewContent() {
		dayViews.forEach { dayView in
			dayView.removeAllTransactionTypes()
			dayView.incomeAmount = 0
			dayView.expenseAmount = 0
		}
	}
	
	private func updateViewBalances(with balanceSummary: BalanceSummary) {
		for dayView in dayViews {
			dayView.expenseAmount = 0.0
			dayView.incomeAmount = 0.0
			if balanceSummary.year > -1 { // -1 year is signal of empty summary
				if dayView.dayOfMonth >= 1 {
					if let dayBal = balanceSummary.balance(forDay: dayView.dayOfMonth) {
						dayView.expenseAmount = Double(dayBal.expense)
						dayView.incomeAmount = Double(dayBal.income)
					}
				}
			}
		}
	}
	
	private func updateViewTransactions(with transactions: [FFFTransaction]) {
		dayViews.forEach { $0.removeAllTransactionTypes() }
		for t in transactions {
			if let dayView = self.dayViewFor(dayOfMonth: t.dayOfMonth) {
				dayView.addTransactionType(t.transactionType)
			}
		}
		dayViews.forEach { $0.setNeedsDisplay($0.bounds) }
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
}


