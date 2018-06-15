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
	case CurrentMonthChanged = "fff_current_month_changed"
	case CurrentDayChanged = "fff_current_day_changed"
	case DataUpdated = "fff_data_updated"
	
	case LoginResponse = "fff_login_response"
	case LogoutResponse = "fff_logout_response"
	
	case ShowEditForm = "fff_show_edit_form"
	
	case OpenBankFile = "fff_open_bank_file"
}
