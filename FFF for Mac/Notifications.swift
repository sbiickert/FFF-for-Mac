//
//  Notifications.swift
//  FFFMobile
//
//  Created by Simon Biickert on 2016-07-15.
//  Copyright © 2016 Simon Biickert. All rights reserved.
//

import Foundation

extension Notification.Name {
	static let appResumed = Notification.Name("fff_app_resumed")

	static let currentMonthChanged = Notification.Name("fff_current_month_changed")
	static let currentDayChanged = Notification.Name("fff_current_day_changed")
	static let dataUpdated = Notification.Name("fff_data_updated")
	
	static let showEditForm = Notification.Name("fff_show_edit_form")
	static let openBankFile = Notification.Name("fff_open_bank_file")
	
	// iOS-specific
	static let infiniteDataLoaded = Notification.Name("fff_infinite_data_loaded")
	static let highlightTransaction = Notification.Name("fff_highlight_transaction")
	
	// Mac-specific
	static let loginResponse = Notification.Name("fff_logged_in")
	static let logoutResponse = Notification.Name("fff_logged_out")
	static let refreshData = Notification.Name("fff_refresh")
	static let dataRefreshed = Notification.Name("fff_refreshed")
	static let transactionsCreated = Notification.Name("fff_transactions_created")

	// Experimenting with Combine
	static let stateChange_MonthlyTransactions = Notification.Name("fff_state_month_t")
	static let stateChange_DailyTransactions = Notification.Name("fff_state_day_t")
	static let stateChange_MonthlyBalance = Notification.Name("fff_state_month_b")
	static let stateChange_MonthlyCategories = Notification.Name("fff_state_month_c")
}
