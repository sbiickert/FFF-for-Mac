//
//  Gateway.swift
//  FFFMobile
//
//  Created by Simon Biickert on 2016-07-15.
//  Copyright © 2016 Simon Biickert. All rights reserved.
//

import Foundation
import Security

let APP_ERROR_DOMAIN = "ca.biickert.fff.ErrorDomain"

enum CredentialsConstants: String {
	case KeychainUsernameIdentifier = "FFFMobileUser"
	case KeychainPasswordIdentifier = "FFFMobilePassword"
}

enum DefaultsKey: String {
	case IncomeTypes = "income_types_key"
	case ExpenseTypes = "expense_types_key"
	case ServerUrl = "server_url_preference"
//	case ServerTokenLifespan = "server_token_lifespan_preference"
//	case UserName = "user_name_preference"
//	case Password = "password_preference"
	//case FastCode = "fast_code_preference" // Switching to TouchID LocalAuthentication
	case SuccessfulLogin = "user_name_password_are_valid_preference"
}

enum RestResource: String {
// For making resource requests
	case TokenResource = "token"
	case TransactionResource = "transaction"
}

enum ResponseKey: String {
// Keys for reponse notifications
	case Success = "success"
	case Error = "error"
	case Sender = "sender"
	case Message = "message"
	case ResourcePath = "path"
	case ResourceNotificationName = "notificationName"
	case ResourceQParams = "queryParams"
	case Transaction = "transaction"
	case Url = "url"
	case Code = "code"
	case FullName = "userName"
	case Key = "key"
	case IncomeTypes = "incomeTypes"
	case ExpenseTypes = "expenseTypes"
	case Transactions = "transactions"
	case Token = "token"
	case BalanceSummary = "summary"
}

enum DateArgOption: String {
	case Year = "Y"
	case YearMonth = "YM"
	case YearMonthDay = "YMD"
}

struct Token {
	static let lifespanInSeconds = 300
	
	public init(token: String) {
		tokenString = token
		expires = Calendar.current.date(byAdding: .second, value: Token.lifespanInSeconds, to: Date())
	}
	
	let tokenString: String
	let expires: Date!
	
	var isExpired: Bool {
		return expires < Date()
	}
}

class Gateway: NSObject, URLSessionDelegate {
	var url: String!
	var userName: String!
	var password: String!
	var fullName: String?
	
	var token: Token?

	static func urlArgumentForDate(_ date: Date, withOption option: DateArgOption) -> String {
		var argumentString = ""
		
		let units: Set<Calendar.Component> = [.day, .month, .year]
		let components = Calendar.current.dateComponents(units, from: date) // Calendar.current.components(units, from: date)
		
		let year = components.year!
		var month = -1
		var day = -1
		
		if option == .YearMonth || option == .YearMonthDay {
			month = components.month!
		}
		if option == .YearMonthDay {
			day = components.day!
		}
		
		argumentString = String(format: "/%d/%d/%d", year, month, day);
		
		return argumentString
	}
	
	override init() {
		
		let defaults = UserDefaults.standard
		self.url = defaults.string(forKey: DefaultsKey.ServerUrl.rawValue);
		super.init()
		
		let (u, p) = Gateway.getStoredCredentials()
		self.userName = String(describing: u)
		self.password = String(describing: p)
		
		// Add notification observers
		let defaultCenter = NotificationCenter.default
		
		defaultCenter.addObserver(self,
		                          selector: #selector(Gateway.loginRequestNotificationReceived(_:)),
		                          name: NSNotification.Name(rawValue: Notifications.LoginRequest.rawValue),
		                          object: nil)
		defaultCenter.addObserver(self,
		                          selector: #selector(Gateway.logoutRequestNotificationReceived(_:)),
		                          name: NSNotification.Name(rawValue: Notifications.LogoutRequest.rawValue),
		                          object: nil)
		defaultCenter.addObserver(self,
		                          selector: #selector(Gateway.resourceRequestNotificationReceived(_:)),
		                          name: NSNotification.Name(rawValue: Notifications.ResourceRequest.rawValue),
		                          object: nil)
		defaultCenter.addObserver(self,
		                          selector: #selector(Gateway.transactionUpdateRequestNotificationReceived(_:)),
		                          name: NSNotification.Name(rawValue: Notifications.TransactionUpdateRequest.rawValue),
		                          object: nil)
	}
	
	func retrieveToken() {
		// Get the latest, just in case they've been updated
		let defaults = UserDefaults.standard
		self.url = defaults.string(forKey: DefaultsKey.ServerUrl.rawValue);
		let (u, p) = Gateway.getStoredCredentials()
		self.userName = String(u!)
		self.password = String(p!)
		
		let fullUrl = String(format: "%@/%@/%@/json?p=%@", self.url, RestResource.TokenResource.rawValue, self.userName, self.password)
		print("Fetching token: \(fullUrl)");
		
		let request = NSMutableURLRequest(url: URL(string: fullUrl)!)
		processRequest(request as URLRequest) {[weak self] info in
			let success = (info[ResponseKey.Success.rawValue] as! NSNumber).boolValue
			if (success) {
				let message = info[ResponseKey.Message.rawValue] as! Message

				//let content = message.content[ResponseKey.Message.rawValue] as! NSDictionary
				let tokenInfo = message.content[ResponseKey.Token.rawValue] as! NSDictionary
				self?.fullName = tokenInfo[ResponseKey.FullName.rawValue] as? String;
				self?.token = Token(token: tokenInfo[ResponseKey.Key.rawValue] as! String)
				print("\(String(describing: self?.fullName)) fetched a key: \(String(describing: self?.token))");
				
				if var waiting = self?.waitingResourceRequests {
					for waitingRequest in waiting {
						self?.retrieveResource(waitingRequest)
					}
					waiting.removeAll()
				}
			}
			
			DispatchQueue.main.sync {
				self?.postLoginNotification(info)
			}
		}
	}
	
	private var waitingResourceRequests = [NSDictionary]()
	
	func retrieveResource(_ userInfo: NSDictionary) {
		if self.token != nil {
			var fullUrl = String(format: "%@/%@/json?token=%@", arguments: [self.url, userInfo[ResponseKey.ResourcePath.rawValue] as! String, self.token!.tokenString])
			
			if let qParams = userInfo[ResponseKey.ResourceQParams.rawValue] as? String {
				fullUrl = fullUrl.appendingFormat("&%@", qParams)
			}
			
			print("Retrieve resource: \(fullUrl)")
			let request = NSMutableURLRequest(url: URL(string: fullUrl)!)
			processRequest(request as URLRequest) { info in
				let mutableInfo = info.mutableCopy() as! NSMutableDictionary
				mutableInfo[ResponseKey.ResourceNotificationName.rawValue] = userInfo[ResponseKey.ResourceNotificationName.rawValue]
				
				DispatchQueue.main.sync {
					self.postResourceReceivedNotification(mutableInfo)
				}
			}
		}
		else {
			waitingResourceRequests.append(userInfo)
			retrieveToken()
		}
	}
	
	func updateTransaction(_ userInfo: NSDictionary) {
		let wrapper = userInfo[ResponseKey.Transaction.rawValue] as! TransactionWrapper
		let transaction = wrapper.transaction!
		var baseUrl = String(format: "%@/%@", arguments: [self.url, RestResource.TransactionResource.rawValue])
		
		if transaction.isNew == false {
			baseUrl = baseUrl.appendingFormat("/%d", transaction.id)
		}
		
		let fullUrl = baseUrl.appendingFormat("?token=%@", self.token!.tokenString)
		print("Update transaction: \(transaction)")

		// Turn the transaction into a POST/PUT body
		let bodyString = self.postBodyForTransaction(transaction)
		let bodyData = bodyString.data(using: String.Encoding.utf8)
		
		let request = NSMutableURLRequest(url: URL(string: fullUrl)!)
		request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "content-type")
		
		if transaction.isNew {
			request.httpMethod = "POST"
			request.httpBody = bodyData
		}
		else {
			if transaction.modificationStatus == .deleted {
				request.httpMethod = "DELETE"
			}
			else {
				request.httpMethod = "PUT"
				request.httpBody = bodyData
			}
		}

		self.processRequest(request as URLRequest) { info in
			DispatchQueue.main.sync{
				self.postTransactionUpdateNotification(info)
			}
		}
	}
	
	func postBodyForTransaction(_ transaction: Transaction) -> String {
		let units: Set<Calendar.Component> = [.day, .month, .year]
		let components = Calendar.current.dateComponents(units, from: transaction.date)
		
		// I suspect that the problems with special characters in the descriptions are caused here. Removing.
		// .stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
		let content = ["tt": String(format: "%d", arguments: [transaction.transactionType!.code]),
		               "amount": String(format: "%.2f", arguments: [transaction.amount]),
		               "description": transaction.description,
		               "y": String(format: "%d", arguments: [components.year!]),
		               "m": String(format: "%d", arguments: [components.month!]),
		               "d": String(format: "%d", arguments: [components.day!])]
		
		var params = [String]()
		for keyValue in content {
			params.append(String(format: "%@=%@", keyValue.0, keyValue.1 ?? ""))
		}
		
		return params.joined(separator: "&")
	}
	
	func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (Foundation.URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
		completionHandler(Foundation.URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
	}
	
	func processRequest(_ request: URLRequest, closure: @escaping (_ info: NSDictionary) -> Void) {
		var info = NSDictionary()
		
		let config = URLSessionConfiguration.default
		let session = Foundation.URLSession(configuration: config, delegate: self, delegateQueue: nil)

		let task = session.dataTask(with: request, completionHandler: {(data: Data?, response: URLResponse?, error: Error?) -> Void in
			if (error != nil) {
				print("Error requesting token: \(String(describing: error))")
				info = [ResponseKey.Success.rawValue: NSNumber(value: false),
					ResponseKey.Error.rawValue: error as AnyObject,
					ResponseKey.Sender.rawValue: self]
			}
			else {
				do {
					let json = try JSONSerialization.jsonObject(with: data!, options: [])
					let dict = json as! NSDictionary
					let message = Message(dictionary: dict)
					if message.isError {
						print("Got error back from server: \(message.code): \(String(describing: message.content[ResponseKey.Code.rawValue]))")
						let swiftDict = self.convertNSDictionary(message.content)
						let messageError = NSError(domain: APP_ERROR_DOMAIN, code: message.code, userInfo: swiftDict)
						info = [ResponseKey.Success.rawValue: NSNumber(value: false),
							ResponseKey.Error.rawValue: messageError,
							ResponseKey.Sender.rawValue: self];
					}
					else {
						// Got a message
						info = [ResponseKey.Success.rawValue: NSNumber(value: true),
							ResponseKey.Message.rawValue: message,
							ResponseKey.Sender.rawValue: self];
					}
				}
				catch {

					print("Malformed JSON requesting token: \(error)");
					info = [ResponseKey.Success.rawValue: NSNumber(value: false),
						ResponseKey.Error.rawValue: error as AnyObject,
						ResponseKey.Sender.rawValue: self];
				}
			}
			
			// Execute closure
			closure(info)
		})
		task.resume()
	}
	
	func convertNSDictionary(_ nsDict:NSDictionary) -> [String: Any] {
		var dict = [String: Any]()
		for key in nsDict.allKeys {
			let sKey = String(describing:key)
			dict[sKey] = nsDict[key]
		}
		return dict
	}
	
	@objc func loginRequestNotificationReceived(_ notification: Notification) {
		DispatchQueue.main.async {
			self.retrieveToken()
		}
	}
	
	@objc func logoutRequestNotificationReceived(_ notification: Notification) {
		self.fullName = nil;
		self.token = nil;
		DispatchQueue.main.async{
			self.postLogoutNotification([:])
		}
	}
	
	@objc func resourceRequestNotificationReceived(_ notification: Notification) {
		DispatchQueue.main.async{
			self.retrieveResource((notification as NSNotification).userInfo! as NSDictionary)
		}
	}
	
	@objc func transactionUpdateRequestNotificationReceived(_ notification: Notification) {
		DispatchQueue.main.async {
			self.updateTransaction((notification as NSNotification).userInfo! as NSDictionary)
		}
	}
	
	func postLoginNotification(_ info: NSDictionary) {
		NotificationCenter.default.post(name: Notification.Name(rawValue: Notifications.LoginResponse.rawValue),
		                                                          object: self,
		                                                          userInfo: info as [NSObject: AnyObject])
	}
	
	func postLogoutNotification(_ info: NSDictionary) {
		NotificationCenter.default.post(name: Notification.Name(rawValue: Notifications.LogoutResponse.rawValue),
		                                                          object: self,
		                                                          userInfo: info as [NSObject: AnyObject])
	}
	
	func postResourceReceivedNotification(_ info: NSDictionary) {
		NotificationCenter.default.post(name: Notification.Name(rawValue: info[ResponseKey.ResourceNotificationName.rawValue] as! String),
		                                                          object: self,
		                                                          userInfo: info as [NSObject: AnyObject])
	}
	
	func postTransactionUpdateNotification(_ info: NSDictionary) {
		NotificationCenter.default.post(name: Notification.Name(rawValue: Notifications.TransactionUpdateResponse.rawValue),
		                                                          object: self,
		                                                          userInfo: info as [NSObject: AnyObject])
	}
	
	// MARK: Secure storage of credentials
	
	
	static let kSecClassGenericPasswordValue = NSString(format: kSecClassGenericPassword);
	static let kSecClassValue = NSString(format: kSecClass);
	static let kSecAttrServiceValue = NSString(format: kSecAttrService);
	static let kSecValueDataValue = NSString(format: kSecValueData);
	static let kSecMatchLimitValue = NSString(format: kSecMatchLimit);
	static let kSecReturnDataValue = NSString(format: kSecReturnData);
	static let kSecMatchLimitOneValue = NSString(format: kSecMatchLimitOne);
	static let kSecAttrAccountValue = NSString(format: kSecAttrAccount);
	
	private static func getStoredString(_ key: NSString) -> NSString? {
		let keychainQuery = NSDictionary(
			objects: [kSecClassGenericPasswordValue,
				key,
				kCFBooleanTrue,
				kSecMatchLimitOneValue],
			forKeys: [kSecClassValue, kSecAttrServiceValue, kSecReturnDataValue, kSecMatchLimitValue]);
		var dataTypeRef: AnyObject?
		let status: OSStatus = SecItemCopyMatching(keychainQuery, &dataTypeRef)
		var value: NSString?
		if (status == errSecSuccess) {
			let retrievedData: Data? = dataTypeRef as? Data
			if let result = NSString(data: retrievedData!, encoding: String.Encoding.utf8.rawValue) {
				value = result
			}
		}
		else {
			print("Nothing was retrieved from the keychain. Status code \(status)")
		}
		return value
	}
	
	static func getStoredCredentials() -> (username: NSString?, password: NSString?) {
		return (username: getStoredString(CredentialsConstants.KeychainUsernameIdentifier.rawValue as NSString),
		        password: getStoredString(CredentialsConstants.KeychainPasswordIdentifier.rawValue as NSString) )
	}
	
	private static func setStoredString(_ key: NSString, value: NSString) {
		let dataFromString: Data = value.data(using: String.Encoding.utf8.rawValue)!;
		let keychainQuery = NSDictionary(
			objects: [kSecClassGenericPasswordValue,
				key,
				dataFromString],
			forKeys: [kSecClassValue, kSecAttrServiceValue, kSecValueDataValue]);
		SecItemDelete(keychainQuery as CFDictionary);
		let _result: OSStatus = SecItemAdd(keychainQuery as CFDictionary, nil);
		if _result != 0 {
			print("Storing string in keychain result: \(_result)")
		}
	}
	
	static func setStoredCredentials(_ username: String, password: String) {
		setStoredString(CredentialsConstants.KeychainUsernameIdentifier.rawValue as NSString, value: username as NSString)
		setStoredString(CredentialsConstants.KeychainPasswordIdentifier.rawValue as NSString, value: password as NSString)
	}
}

struct DataFormatter {
	static let fffDateFormat = "yyyy'-'MM'-'dd"
	static var dateFormatter: DateFormatter?
	static func _initDateFormatter() {
		dateFormatter = DateFormatter()
		dateFormatter?.dateFormat = fffDateFormat
		dateFormatter?.timeZone = TimeZone.current
	}
	
	
	static func dateFromFFFDateString(_ dateString: String) -> Date? {
		if (dateFormatter == nil) {
			_initDateFormatter()
		}
		return dateFormatter!.date(from: dateString)
	}
	
	static func fffDateStringFromDate(_ date: Date) -> String {
		if (dateFormatter == nil) {
			_initDateFormatter()
		}
		return dateFormatter!.string(from: date)
	}
	
}
