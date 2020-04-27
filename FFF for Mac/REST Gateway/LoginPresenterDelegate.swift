//
//  LoginPresenterDelegate.swift
//  FFF ∞
//
//  Created by Simon Biickert on 2019-08-24.
//  Copyright © 2019 ii Softwerks. All rights reserved.
//

import AppKit

typealias RequestAndCallback = (URLRequest, (RequestResult) -> Void)
protocol LoginPresenterDelegate {
	func showLogin();
}
