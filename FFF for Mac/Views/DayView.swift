//
//  DayView.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-02-25.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa

class DayView: NSView {

	private var transactionTypes = Set<TransactionType>()
	
	func addTransactionType(_ type: TransactionType?) {
		if type != nil {
			transactionTypes.insert(type!)
		}
	}
	
	func removeAllTransactionTypes() {
		transactionTypes.removeAll()
	}
	
	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
	}
	
	required init?(coder decoder: NSCoder) {
		super.init(coder: decoder)
	}

	var dayOfMonth = -1 {
		didSet { setNeedsDisplay(self.bounds) }
	}
	
	var incomeAmount: Double = 0.0 {
		didSet { setNeedsDisplay(self.bounds) }
	}
	var incomeNumber: NSNumber {
		get {
			return NSNumber(floatLiteral: incomeAmount)
		}
	}
	
	var expenseAmount: Double = 0.0 {
		didSet { setNeedsDisplay(self.bounds) }
	}
	var expenseNumber: NSNumber {
		get {
			return NSNumber(floatLiteral: expenseAmount)
		}
	}
	
	var isDaySelected = false {
		didSet { setNeedsDisplay(self.bounds) }
	}
	
	var inset: CGFloat {
		return 4.0
	}
	var cornerRadius: CGFloat {
		return bounds.size.width * 0.05
	}
	var outlineWeight: CGFloat {
		return CGFloat(2.0)
	}
	var backgroundColor = NSColor.red {
		didSet { setNeedsDisplay(self.bounds) }
	}
	
	var dayOfMonthTextAttributes: Dictionary<NSAttributedString.Key, NSObject> {
		get {
			let paragraphStyle = NSMutableParagraphStyle()
			paragraphStyle.lineBreakMode = .byTruncatingTail
			paragraphStyle.alignment = .left
			let nameTextAttributes = [
				NSAttributedString.Key.font:NSFont.boldSystemFont(ofSize: 12),
				NSAttributedString.Key.foregroundColor: NSColor.controlTextColor,
				NSAttributedString.Key.paragraphStyle: paragraphStyle]
			return nameTextAttributes
		}
	}
	
	var incomeAmountTextAttributes: Dictionary<NSAttributedString.Key, NSObject> {
		get {
			let paragraphStyle = NSMutableParagraphStyle()
			paragraphStyle.lineBreakMode = .byTruncatingTail
			paragraphStyle.alignment = .right
			let nameTextAttributes = [
				NSAttributedString.Key.font:NSFont.systemFont(ofSize: 11),
				NSAttributedString.Key.foregroundColor: NSColor.controlTextColor,
				NSAttributedString.Key.paragraphStyle: paragraphStyle]
			return nameTextAttributes
		}
	}
	
	var expenseAmountTextAttributes: Dictionary<NSAttributedString.Key, NSObject> {
		get {
			let expenseTextColor = NSColor(named: NSColor.Name("expenseTextColor")) ?? NSColor.purple
			let paragraphStyle = NSMutableParagraphStyle()
			paragraphStyle.lineBreakMode = .byTruncatingTail
			paragraphStyle.alignment = .right
			let nameTextAttributes = [
				NSAttributedString.Key.font:NSFont.systemFont(ofSize: 11),
				NSAttributedString.Key.foregroundColor: expenseTextColor,
				NSAttributedString.Key.paragraphStyle: paragraphStyle]
			return nameTextAttributes
		}
	}
	
	var emojiTextAttributes: Dictionary<NSAttributedString.Key, NSObject> {
		get {
			let paragraphStyle = NSMutableParagraphStyle()
			paragraphStyle.lineBreakMode = .byCharWrapping
			paragraphStyle.alignment = .left
			let nameTextAttributes = [
				NSAttributedString.Key.font:NSFont.systemFont(ofSize: 11),
				NSAttributedString.Key.foregroundColor: NSColor.textColor,
				NSAttributedString.Key.paragraphStyle: paragraphStyle]
			return nameTextAttributes
		}
	}

    override func draw(_ dirtyRect: NSRect) {
		if isHidden || dayOfMonth < 1 {
			return
		}
		
		//let context = NSGraphicsContext.current
		let drawingRect = bounds.insetBy(dx: inset, dy: inset)
		
		let dayBackgroundPath = NSBezierPath(roundedRect: drawingRect, xRadius: cornerRadius, yRadius: cornerRadius)
		
		dayBackgroundPath.addClip()
		backgroundColor.setFill()
		dayBackgroundPath.fill()
		
		NSColor.shadowColor.setStroke()
		dayBackgroundPath.lineWidth = outlineWeight
		dayBackgroundPath.stroke()
		
		var insetRect = drawingRect.insetBy(dx: inset, dy: inset)
		let dayAttrString = NSAttributedString(string: "\(dayOfMonth)", attributes: dayOfMonthTextAttributes)
		dayAttrString.draw(in: insetRect)
		var offsetY:CGFloat = dayAttrString.size().height

		let currFormatter = NumberFormatter()
		currFormatter.numberStyle = .currency

		let eAttrString = NSAttributedString(string: currFormatter.string(from: expenseNumber) ?? "", attributes: expenseAmountTextAttributes)
		insetRect.origin.y -= offsetY
		offsetY = eAttrString.size().height
		if expenseAmount > 0 {
			eAttrString.draw(in: insetRect)
		}
		
		let iAttrString = NSAttributedString(string: currFormatter.string(from: incomeNumber) ?? "", attributes: incomeAmountTextAttributes)
		insetRect.origin.y -= offsetY
		offsetY = iAttrString.size().height
		if incomeAmount > 0 {
			iAttrString.draw(in: insetRect)
		}
		
		if transactionTypes.count > 0 {
			insetRect.origin.y -= offsetY + 8 // 8 is padding
			var ttString = ""
			for tt in transactionTypes {
				ttString += tt.emoji
			}
			let attrString = NSAttributedString(string: ttString, attributes: emojiTextAttributes)
			attrString.draw(in: insetRect)
		}
	}
	
}
