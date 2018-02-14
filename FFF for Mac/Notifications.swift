//
//  Notifications.swift
//  FFFMobile
//
//  Created by Simon Biickert on 2016-07-15.
//  Copyright © 2016 Simon Biickert. All rights reserved.
//

import Foundation

enum NotificationKeys: String {
	case CurrentDateNotificationName = "fff_current_date_response_notification_name"
}

enum Notifications: String {
	case CurrentDateRequest = "fff_current_date_request"
	case CurrentDateChanged = "fff_current_date_changed"
	case DataUpdated = "fff_data_updated"
	
	case TransactionUpdateRequest = "fff_transaction_update_request"
	case ResourceRequest = "fff_resource_request"
	case LoginRequest = "fff_login_request"
	case LogoutRequest = "fff_logout_request"
	
	case TransactionUpdateResponse = "fff_transaction_update_response"
	
	// Resource request notifications are defined by the callers --sjb
	
	case LoginResponse = "fff_login_response"
	case LogoutResponse = "fff_logout_response"
	
	case ShowTransactionsForDay = "fff_show_transactions_for_day"
}