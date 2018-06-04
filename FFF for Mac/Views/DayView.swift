//
//  DayView.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-02-25.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa

class DayView: NSView {

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
		return bounds.size.width * 0.05
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
	
	var dayOfMonthTextAttributes: Dictionary<NSAttributedStringKey, NSObject> {
		get {
			let paragraphStyle = NSMutableParagraphStyle()
			paragraphStyle.lineBreakMode = .byTruncatingTail
			paragraphStyle.alignment = .left
			let nameTextAttributes = [
				NSAttributedStringKey.font:NSFont.boldSystemFont(ofSize: 12),
				NSAttributedStringKey.paragraphStyle: paragraphStyle]
			return nameTextAttributes
		}
	}
	
	var incomeAmountTextAttributes: Dictionary<NSAttributedStringKey, NSObject> {
		get {
			let paragraphStyle = NSMutableParagraphStyle()
			paragraphStyle.lineBreakMode = .byTruncatingTail
			paragraphStyle.alignment = .right
			let nameTextAttributes = [
				NSAttributedStringKey.font:NSFont.systemFont(ofSize: 11),
				NSAttributedStringKey.foregroundColor: NSColor.black,
				NSAttributedStringKey.paragraphStyle: paragraphStyle]
			return nameTextAttributes
		}
	}
	
	var expenseAmountTextAttributes: Dictionary<NSAttributedStringKey, NSObject> {
		get {
			let paragraphStyle = NSMutableParagraphStyle()
			paragraphStyle.lineBreakMode = .byTruncatingTail
			paragraphStyle.alignment = .right
			let nameTextAttributes = [
				NSAttributedStringKey.font:NSFont.systemFont(ofSize: 11),
				NSAttributedStringKey.foregroundColor: NSColor.red,
				NSAttributedStringKey.paragraphStyle: paragraphStyle]
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
		NSString(string: "\(dayOfMonth)").draw(in: insetRect, withAttributes: dayOfMonthTextAttributes)
		
		let currFormatter = NumberFormatter()
		currFormatter.numberStyle = .currency

		var incomeOffsetY:CGFloat = 0.0
		if expenseAmount > 0 {
			let attrString = NSAttributedString(string: currFormatter.string(from: expenseNumber) ?? "", attributes: expenseAmountTextAttributes)
			attrString.draw(in: insetRect)
			incomeOffsetY = attrString.size().height
		}
		if incomeAmount > 0 {
			insetRect.origin.y -= incomeOffsetY
			let attrString = NSAttributedString(string: currFormatter.string(from: incomeNumber) ?? "", attributes: incomeAmountTextAttributes)
			attrString.draw(in: insetRect)
		}
	}
	
}
