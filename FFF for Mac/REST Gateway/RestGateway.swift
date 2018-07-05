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
	case BalanceResource = "balance"
	case SearchResource = "search"
	case SummaryResource = "summary"
	case TokenResource = "token"
	case TransactionResource = "transaction"
	case TransactionsResource = "transactions"
	case TransactionTypesResource = "transactiontype"
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


class RestGateway: NSObject, Gateway, URLSessionDelegate {
	private static let debugURL:String? = nil // "http://localhost/FFF/services/web"  // set to nil to ignore
	private static let defaultURL = "https://www.biickert.ca/FFF4/services/web/app.php"
	static let shared = RestGateway()
	
	var userName: String!
	var fullName: String?

	private(set) var url: String!
	private var password: String!
	private var session: URLSession?
	private var token: Token?
	
	private override init() {
		super.init()
		if RestGateway.debugURL != nil {
			self.url = RestGateway.debugURL!
		}
		else if let defaultsUrl = UserDefaults.standard.string(forKey: DefaultsKey.ServerUrl.rawValue) {
			self.url = defaultsUrl
		}
		else {
			self.url = RestGateway.defaultURL
		}
		let config = URLSessionConfiguration.default
		session = Foundation.URLSession(configuration: config, delegate: self, delegateQueue: nil)
		
		let (u, p) = RestGateway.getStoredCredentials()
		self.userName = String(describing: u)
		self.password = String(describing: p)
	}
	
	var isDebugging: Bool {
		return RestGateway.debugURL != nil
	}
	
	// MARK: Public API
	var isLoggedIn: Bool {
		get {
			return token != nil && token!.isExpired == false
		}
	}
	func login() {
		retrieveToken()
	}
	
	func logout() {
		self.fullName = nil;
		self.token = nil;
		self.postLogoutNotification()
	}
	
	func getTransaction(withID id:Int, callback: @escaping (Message) -> Void) {
		// url/transaction/id/json?token=
		let fullUrl = String(format: "%@/%@/%@/json?token=%@",
							 self.url,
							 RestResource.TransactionResource.rawValue,
							 String(id),
							 self.token!.tokenString)
		print("Fetching transaction: \(fullUrl)");
		let request = NSMutableURLRequest(url: URL(string: fullUrl)!)
		self.makeRequest(request: request, callback: callback)
	}
	
	func createTransaction(transaction: Transaction, callback: @escaping (Message) -> Void) {
		// POST url/transaction?token=
		let fullUrl = String(format: "%@/%@?token=%@",
							 self.url,
							 RestResource.TransactionResource.rawValue,
							 self.token!.tokenString)

		// Turn the transaction into a POST body
		let bodyString = self.postBodyForTransaction(transaction)
		let bodyData = bodyString.data(using: String.Encoding.utf8)

		let request = NSMutableURLRequest(url: URL(string: fullUrl)!)
		request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "content-type")
		request.httpMethod = "POST"
		request.httpBody = bodyData
		self.makeRequest(request: request, callback: callback)
	}
	
	func updateTransaction(transaction: Transaction, callback: @escaping (Message) -> Void) {
		// PUT url/transaction/id?token=
		let fullUrl = String(format: "%@/%@/%@?token=%@",
							 self.url,
							 RestResource.TransactionResource.rawValue,
							 String(transaction.id),
							 self.token!.tokenString)
		
		// Turn the transaction into a POST body
		let bodyString = self.postBodyForTransaction(transaction)
		let bodyData = bodyString.data(using: String.Encoding.utf8)
		
		let request = NSMutableURLRequest(url: URL(string: fullUrl)!)
		request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "content-type")
		request.httpMethod = "PUT"
		request.httpBody = bodyData
		self.makeRequest(request: request, callback: callback)
	}

	func deleteTransaction(transaction: Transaction, callback: @escaping (Message) -> Void) {
		self.deleteTransaction(withID: transaction.id, callback: callback)
	}
	
	func deleteTransaction(withID id:Int, callback: @escaping (Message) -> Void) {
		// DELETE url/transaction/id?token=
		let fullUrl = String(format: "%@/%@/%@?token=%@",
							 self.url,
							 RestResource.TransactionResource.rawValue,
							 String(id),
							 self.token!.tokenString)
		let request = NSMutableURLRequest(url: URL(string: fullUrl)!)
		request.httpMethod = "DELETE"
		self.makeRequest(request: request, callback: callback)
	}

	func getTransactions(forYear year:Int, month:Int,
						 callback: @escaping (Message) -> Void) {
		self.getTransactions(forYear: year, month: month, day:-1, limitedTo: nil, callback: callback)
	}

	func getTransactions(forYear year:Int, month:Int, day:Int,
						 callback: @escaping (Message) -> Void) {
		self.getTransactions(forYear: year, month: month, day: day, limitedTo: nil, callback: callback)
	}

	func getTransactions(forYear year:Int, month:Int, day: Int, limitedTo tt:TransactionType?,
						 callback: @escaping (Message) -> Void) {
		// url/transactions/year/month/day/json?token=
		var fullUrl = String(format: "%@/%@/%@/%@/%@/json?token=%@",
							 self.url,
							 RestResource.TransactionsResource.rawValue,
							 String(year),
							 String(month),
							 String(day),
							 self.token!.tokenString)
		if tt != nil {
			fullUrl += "&tt=" + String(tt!.code)
		}
		print("Fetching transactions: \(fullUrl)");
		let request = NSMutableURLRequest(url: URL(string: fullUrl)!)
		self.makeRequest(request: request, callback: callback)
	}
	
	func getSearchResults(_ query:String ,
							callback: @escaping (Message) -> Void) {
		// url/search/json?token=&q=
		let fullUrl = String(format: "%@/%@/json?token=%@&q=%@",
							 self.url,
							 RestResource.SearchResource.rawValue,
							 self.token!.tokenString,
							 query)
		print("Searching for transactions: \(fullUrl)");
		let request = NSMutableURLRequest(url: URL(string: fullUrl)!)
		self.makeRequest(request: request, callback: callback)
	}
	
	func getTransactionTypes(callback: @escaping (Message) -> Void) {
		// url/transactiontype/json
		let fullUrl = String(format: "%@/%@/json",
							 self.url,
							 RestResource.TransactionTypesResource.rawValue)
		print("Fetching transaction types: \(fullUrl)");
		let request = NSMutableURLRequest(url: URL(string: fullUrl)!)
		self.makeRequest(request: request, callback: callback)
	}
	
	func getBalanceSummary(forYear year:Int, month:Int,
						   callback: @escaping (Message) -> Void) {
		// url/balance/year/month/day/json?token=
		let fullUrl = String(format: "%@/%@/%@/%@/-1/json?token=%@",
							 self.url,
							 RestResource.BalanceResource.rawValue,
							 String(year),
							 String(month),
							 self.token!.tokenString)
		print("Fetching balance summary: \(fullUrl)");
		let request = NSMutableURLRequest(url: URL(string: fullUrl)!)
		self.makeRequest(request: request, callback: callback)
	}
	
	func getCategorySummary(forYear year:Int, month:Int,
							callback: @escaping (Message) -> Void) {
		// url/summary/year/month/day/json?token=
		let fullUrl = String(format: "%@/%@/%@/%@/-1/json?token=%@",
							 self.url,
							 RestResource.SummaryResource.rawValue,
							 String(year),
							 String(month),
							 self.token!.tokenString)
		print("Fetching category summary: \(fullUrl)");
		let request = NSMutableURLRequest(url: URL(string: fullUrl)!)
		self.makeRequest(request: request, callback: callback)
	}
	
	// MARK: Private API
	
	private func makeRequest(request:NSURLRequest, callback: @escaping (Message) -> Void) {
		processRequest(request as URLRequest) {info in
			let success = (info[ResponseKey.Success.rawValue] as! NSNumber).boolValue
			if (success) {
				let message = info[ResponseKey.Message.rawValue] as! Message
				if message.code == 201 {
					// A transaction was created. Fetch it and return it.
					self.getTransaction(withID: message.createdTransactionID!, callback: callback)
				}
				else {
					callback(message)
				}
			}
		}
	}
	
	private func retrieveToken() {
		// Get the latest, just in case they've been updated
		let (u, p) = RestGateway.getStoredCredentials()
		self.userName = String(u!)
		self.password = String(p!)
		
		let fullUrl = String(format: "%@/%@/%@/json?p=%@", self.url, RestResource.TokenResource.rawValue, self.userName, self.password)
		print("Fetching token: \(fullUrl)");
		
		let request = NSMutableURLRequest(url: URL(string: fullUrl)!)
		processRequest(request as URLRequest) {[weak self] info in
			let success = (info[ResponseKey.Success.rawValue] as! NSNumber).boolValue
			if (success) {
				let message = info[ResponseKey.Message.rawValue] as! Message
				let tokenInfo = message.content[ResponseKey.Token.rawValue] as! NSDictionary
				self?.fullName = tokenInfo[ResponseKey.FullName.rawValue] as? String;
				self?.token = Token(token: tokenInfo[ResponseKey.Key.rawValue] as! String)
				print("\(String(describing: self?.fullName)) fetched a key: \(String(describing: self?.token))");
				
				DispatchQueue.main.async {
					self?.postLoginNotification(info)
				}
			}
			else {
				DispatchQueue.main.async {
					self?.login()
				}
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
		
		
		let task = session?.dataTask(with: request, completionHandler: {(data: Data?, response: URLResponse?, error: Error?) -> Void in
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
		task?.resume()
	}
	
	func convertNSDictionary(_ nsDict:NSDictionary) -> [String: Any] {
		var dict = [String: Any]()
		for key in nsDict.allKeys {
			let sKey = String(describing:key)
			dict[sKey] = nsDict[key]
		}
		return dict
	}
	
	func postLoginNotification(_ info: NSDictionary) {
		NotificationCenter.default.post(name: Notification.Name(rawValue: Notifications.LoginResponse.rawValue),
										object: self,
										userInfo: info as [NSObject: AnyObject])
	}
	
	func postLogoutNotification() {
		NotificationCenter.default.post(name: Notification.Name(rawValue: Notifications.LogoutResponse.rawValue),
										object: self,
										userInfo: nil)
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
