//
//  RestGateway.swift
//  FFF ∞
//
//  Created by Simon Biickert on 2016-07-15.
//  Copyright © 2016 Simon Biickert. All rights reserved.
//

import Foundation
import Security

let APP_ERROR_DOMAIN = "ca.biickert.fff.ErrorDomain"

// MARK: Types used
enum CredentialsConstants: String {
	case KeychainUsernameIdentifier = "FFFMobileUser"
	case KeychainPasswordIdentifier = "FFFMobilePassword"
}

enum DefaultsKey: String {
	case IncomeTypes = "income_types_key"
	case ExpenseTypes = "expense_types_key"
	case ServerUrl = "server_url_preference"
	case SuccessfulLogin = "user_name_password_are_valid_preference"
	case RecentTransactions = "recent_transactions"
}

enum RestResource: String {
	// For making resource requests
	case BalanceResource = "balance"
	case SearchResource = "search"
	case SeriesResource = "series"
	case SummaryResource = "summary"
	case TransactionResource = "transaction"
	case TransactionsResource = "transactions"
	case TransactionTypesResource = "transactiontypes"
	case HeartbeatResource = "heartbeat"
}

enum TransactionTypeCategory: String {
	case All = "ALL"
	case Expense = "EXP"
	case Income = "INC"
}

enum DateArgOption: String {
	case Year = "Y"
	case YearMonth = "YM"
	case YearMonthDay = "YMD"
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

struct CodableTransaction: Codable {
	var id: Int = 0
	var tt: Int = 0
	var amount: Float = 0.0
	var description: String?
	var seriesid: String?
	var y: Int = 0
	var m: Int = 0
	var d: Int = 0
	
	init(transaction:FFFTransaction) {
		id = transaction.id
		tt = transaction.transactionType.id
		amount = transaction.amount
		description = transaction.description
		seriesid = transaction.seriesID
		let components = Calendar.current.dateComponents(AppDelegate.unitsYMD, from: transaction.date)
		y = components.year!
		m = components.month!
		d = components.day!
	}
	
	var date: Date {
		if let theDate = Calendar.current.date(from: DateComponents(year: y, month: m, day: d)) {
			return theDate
		}
		return Date()
	}
	
	var transaction: FFFTransaction {
		let t = FFFTransaction(id: id,
							   amount: amount,
							   transactionType: TransactionType.transactionType(forCode: tt) ?? TransactionType.defaultExpense,
							   description: description ?? "",
							   date: date,
							   seriesID: seriesid,
							   modificationStatus: .clean)
		return t
	}
}

struct CodableOpResult: Codable {
	var message: String
	var ids: [Int]
}

struct RequestResult {
	var isError = false
	var code = 0
	var text: String? // JSON encoded
	var data: Data? // JSON binary
}


// MARK: The Gateway Class
class RestGateway: NSObject, URLSessionDelegate {
	// Running in PHP server: http://localhost:8000
	// Running in MAMP: http://localhost:8888/FFF6/public
	private static let debugURL:String? = nil // "http://localhost:8888/FFF6/public"  // set to nil to ignore
	private static let defaultURL = "https://www.biickert.ca/FFF6/public"
	static let shared = RestGateway()

	var userName: String! {
		let (u, _) = RestGateway.getStoredCredentials()
		return u ?? ""
	}
	private var password: String! {
		let (_, p) = RestGateway.getStoredCredentials()
		return p ?? ""
	}

	private(set) var url: String!
	private var _session: URLSession?
	
	private override init() {
		super.init()
		if RestGateway.debugURL != nil {
			self.url = RestGateway.debugURL!
		}
//		else if let defaultsUrl = UserDefaults.standard.string(forKey: DefaultsKey.ServerUrl.rawValue) {
//			self.url = defaultsUrl
//		}
		else {
			self.url = RestGateway.defaultURL
		}
		let config = URLSessionConfiguration.default
		_session = Foundation.URLSession(configuration: config, delegate: self, delegateQueue: nil)
	}
	
	var session: URLSession? {
		return _session
	}

	var isDebugging: Bool {
		return RestGateway.debugURL != nil
	}
	
	private var httpBasicLogin:String {
		let loginString = String(format: "%@:%@", userName, password)
		let loginData = loginString.data(using: String.Encoding.utf8)!
		return loginData.base64EncodedString()
	}
	
	// MARK: Request Factory - GET
	func createRequestGetTransaction(withID id:Int) -> URLRequest {
		// url/transaction/id.json
		let fullUrl = String(format: "%@/%@/%@.json",
							 self.url,
							 RestResource.TransactionResource.rawValue,
							 String(id))
		print("Fetching transaction: \(fullUrl)");
		var request = URLRequest(url: URL(string: fullUrl)!)
		request.setValue("Basic \(httpBasicLogin)", forHTTPHeaderField: "Authorization")
		return request
	}

	func createRequestGetTransactions(forYear year:Int, month:Int) -> URLRequest {
		return self.createRequestGetTransactions(forYear: year, month: month, day:-1, limitedTo: nil)
	}

	func createRequestGetTransactions(forYear year:Int, month:Int, day:Int) -> URLRequest {
		return self.createRequestGetTransactions(forYear: year, month: month, day: day, limitedTo: nil)
	}

	func createRequestGetTransactions(forYear year:Int, month:Int, day: Int, limitedTo tt:TransactionType?) -> URLRequest {
		// url/transactions/year/month/day/json
		var fullUrl = String(format: "%@/%@/%@/%@/%@/json",
							 self.url,
							 RestResource.TransactionsResource.rawValue,
							 String(year),
							 String(month),
							 String(day))
		if tt != nil {
			fullUrl += "?tt=" + String(tt!.id)
		}
		print("Fetching transactions: \(fullUrl)");
		var request = URLRequest(url: URL(string: fullUrl)!)
		request.setValue("Basic \(httpBasicLogin)", forHTTPHeaderField: "Authorization")
		return request
	}
	
	func createRequestGetTransactionSeries(withID id:String) -> URLRequest {
		// url/transactions/seriesID.json
		let fullUrl = String(format: "%@/%@/%@/%@.json",
							 self.url,
							 RestResource.TransactionsResource.rawValue,
							 RestResource.SeriesResource.rawValue,
							 id)
		print("Getting transactions in series: \(fullUrl)");
		var request = URLRequest(url: URL(string: fullUrl)!)
		request.setValue("Basic \(httpBasicLogin)", forHTTPHeaderField: "Authorization")
		return request
	}
	
	func createRequestGetTransactions(withIDs tids:[Int]) -> URLRequest {
		// url/transactions/json
		var fullUrl = String(format: "%@/%@/json",
							 self.url,
							 RestResource.TransactionsResource.rawValue)
		print("Getting transactions with ids: \(tids)");
		
		// Turn the transaction IDs into a GET query
		var tidStrings = [String]()
		for tid in tids { tidStrings.append(String(tid)) }
		fullUrl += "?tids=" + tidStrings.joined(separator: ",")

		var request = URLRequest(url: URL(string: fullUrl)!)
		request.setValue("Basic \(httpBasicLogin)", forHTTPHeaderField: "Authorization")
		return request
	}
	
	func createRequestGetSearchResults(_ query:String) -> URLRequest {
		// url/search/json?q=
		assert(query.trimmingCharacters(in: .whitespaces).isEmpty == false, "Empty query passed to createRequestGetSearchResults(:)")
		let fullUrl = String(format: "%@/%@/json?q=%@",
							 self.url,
							 RestResource.SearchResource.rawValue,
							 query)
		print("Searching for transactions: \(fullUrl)");
		var request = URLRequest(url: URL(string: fullUrl)!)
		request.setValue("Basic \(httpBasicLogin)", forHTTPHeaderField: "Authorization")
		return request
	}
	
	func createRequestGetSearchResults(_ query:String, from:Date, to:Date) -> URLRequest {
		// url/search/json?q=&from=&to=
		let fromString = DataFormatter.fffDateStringFromDate(from)
		let toString = DataFormatter.fffDateStringFromDate(to)
		let fullUrl = String(format: "%@/%@/json?q=%@&from=%@&to=%@",
							 self.url,
							 RestResource.SearchResource.rawValue,
							 query, fromString, toString)
		print("Searching for transactions: \(fullUrl)");
		var request = URLRequest(url: URL(string: fullUrl)!)
		request.setValue("Basic \(httpBasicLogin)", forHTTPHeaderField: "Authorization")
		return request
	}

	func createRequestGetTransactionTypes(category:TransactionTypeCategory = .All) -> URLRequest {
		// url/transactiontypes/json
		let fullUrl = String(format: "%@/%@/%@.json",
							 self.url,
							 RestResource.TransactionTypesResource.rawValue,
							 category.rawValue)
		print("Fetching transaction types: \(fullUrl)");
		let request = URLRequest(url: URL(string: fullUrl)!)
		return request
	}

	func createRequestGetBalanceSummary(forYear year:Int, month:Int) -> URLRequest {
		// url/balance/year/month/day/json
		let fullUrl = String(format: "%@/%@/%@/%@/-1/json",
							 self.url,
							 RestResource.BalanceResource.rawValue,
							 String(year),
							 String(month))
		print("Fetching balance summary: \(fullUrl)");
		var request = URLRequest(url: URL(string: fullUrl)!)
		request.setValue("Basic \(httpBasicLogin)", forHTTPHeaderField: "Authorization")
		return request
	}
	
	func createRequestGetCategorySummary(forYear year:Int, month:Int) -> URLRequest {
		// url/summary/year/month/json
		let fullUrl = String(format: "%@/%@/%@/%@/json",
							 self.url,
							 RestResource.SummaryResource.rawValue,
							 String(year),
							 String(month))
		print("Fetching category summary: \(fullUrl)");
		var request = URLRequest(url: URL(string: fullUrl)!)
		request.setValue("Basic \(httpBasicLogin)", forHTTPHeaderField: "Authorization")
		return request
	}
	
	func createRequestGetHeartbeat() -> URLRequest {
		// url/heartbeat
		let fullUrl = String(format: "%@/%@",
							 self.url,
							 RestResource.HeartbeatResource.rawValue)
		print("Checking login credentials with heartbeat: \(fullUrl)");
		var request = URLRequest(url: URL(string: fullUrl)!)
		request.setValue("Basic \(httpBasicLogin)", forHTTPHeaderField: "Authorization")
		return request
	}

	// MARK: Request Factory - POST
	func createRequestCreateTransactions(transactions: [FFFTransaction]) -> URLRequest {
		for t in transactions {
			assert(t.isValid, "Attempt to create an invalid transaction")
		}
		// url/transactions
		let fullUrl = String(format: "%@/%@?returnTransactions=true",
							 self.url,
							 RestResource.TransactionsResource.rawValue)
		print("Creating transactions");

		// Turn the transactions into a POST body
		let bodyString = self.postBodyForTransactions(transactions)
		let bodyData = bodyString.data(using: String.Encoding.utf8)
		
		var request = URLRequest(url: URL(string: fullUrl)!)
		request.setValue("Basic \(httpBasicLogin)", forHTTPHeaderField: "Authorization")
		request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "content-type")
		request.httpMethod = "POST"
		request.httpBody = bodyData
		return request
	}

	// MARK: Request Factory - PUT
	func createRequestUpdateTransactions(transactions: [FFFTransaction]) -> URLRequest {
		for t in transactions {
			assert(t.isValid, "Attempt to update a transaction with invalid data")
		}
		// PUT url/transactions/id
		let fullUrl = String(format: "%@/%@",
							 self.url,
							 RestResource.TransactionsResource.rawValue)
		
		// Turn the transactions into a POST body
		let bodyString = self.postBodyForTransactions(transactions)
		let bodyData = bodyString.data(using: String.Encoding.utf8)
		
		var request = URLRequest(url: URL(string: fullUrl)!)
		request.setValue("Basic \(httpBasicLogin)", forHTTPHeaderField: "Authorization")
		request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "content-type")
		request.httpMethod = "PUT"
		request.httpBody = bodyData
		return request
	}

	// MARK: Request Factory - DELETE
	func createRequestDeleteTransactions(transactions: [FFFTransaction]) -> URLRequest {
		return self.createRequestDeleteTransactions(withIDs: transactions.map { $0.id })
	}
	
	func createRequestDeleteTransactions(withIDs tids:[Int]) -> URLRequest {
		// DELETE url/transactions
		let fullUrl = String(format: "%@/%@",
							 self.url,
							 RestResource.TransactionsResource.rawValue)
		
		// Turn the transaction IDs into a POST body
		var bodyData:Data? = nil
		let jsonEncoder = JSONEncoder()
		do {
			let jsonData = try jsonEncoder.encode(tids)
			bodyData = String(data: jsonData, encoding: .utf8)!.data(using: .utf8)
		}
		catch {
			print("Error encoding transaction IDs")
		}

		var request = URLRequest(url: URL(string: fullUrl)!)
		request.setValue("Basic \(httpBasicLogin)", forHTTPHeaderField: "Authorization")
		request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "content-type")
		request.httpMethod = "DELETE"
		request.httpBody = bodyData
		return request
	}
	
	
	// MARK: Making Requests
	private func postBodyForTransactions(_ transactions: [FFFTransaction]) -> String {
		// Convert transaction to JSON here
		var simpleTransactions: [CodableTransaction] = []
		for t in transactions { simpleTransactions.append(CodableTransaction(transaction: t)) }
		let jsonEncoder = JSONEncoder()
		do {
			let jsonData = try jsonEncoder.encode(simpleTransactions)
			let jsonString = String(data: jsonData, encoding: .utf8)!
			return jsonString
		}
		catch {
			return "Error encoding transactions"
		}
	}
	
	func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (Foundation.URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
		completionHandler(Foundation.URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
	}
	
	// MARK: Secure storage of credentials
	
//	static let kSecClassGenericPasswordValue = NSString(format: kSecClassGenericPassword);
//	static let kSecClassValue = NSString(format: kSecClass);
//	static let kSecAttrServiceValue = NSString(format: kSecAttrService);
//	static let kSecValueDataValue = NSString(format: kSecValueData);
//	static let kSecMatchLimitValue = NSString(format: kSecMatchLimit);
//	static let kSecReturnDataValue = NSString(format: kSecReturnData);
//	static let kSecMatchLimitOneValue = NSString(format: kSecMatchLimitOne);
//	static let kSecAttrAccountValue = NSString(format: kSecAttrAccount);
	
	enum CredentialStorageMode {
		case Temporary
		case Stored
	}
	
	static var credentialStorageMode: CredentialStorageMode = .Temporary
	private static var tempCredentials = (username: "", password: "")
	
	static func forgetUser() {
		setStoredCredentials("", password: "")
	}
	
	private static var protectionSpace: URLProtectionSpace {
		let ps = URLProtectionSpace(host: "localhost", port: 8888, protocol: "http", realm: nil, authenticationMethod: "http")
		return ps
	}
	
	static func setStoredCredentials(_ username: String, password: String) {
		if credentialStorageMode == .Stored {
			let creds = URLCredential(user: username, password: password, persistence: .permanent)
			URLCredentialStorage.shared.setDefaultCredential(creds, for: protectionSpace)
		}
		else {
			tempCredentials = (username, password)
		}
	}
	
	static func getStoredCredentials() -> (username: String?, password: String?) {
		if credentialStorageMode == .Stored {
			let creds = URLCredentialStorage.shared.defaultCredential(for: protectionSpace)
			return (username: creds?.user, password: creds?.password)
		}
		else {
			return tempCredentials
		}
	}
	
//	private static func getStoredString(_ key: String) -> String? {
//		let keychainQuery = NSDictionary(
//			objects: [kSecClassGenericPasswordValue,
//					  key,
//					  kCFBooleanTrue as Any,
//					  kSecMatchLimitOneValue],
//			forKeys: [kSecClassValue, kSecAttrServiceValue, kSecReturnDataValue, kSecMatchLimitValue]);
//		var dataTypeRef: AnyObject?
//		let status: OSStatus = SecItemCopyMatching(keychainQuery, &dataTypeRef)
//		var value: NSString?
//		if (status == errSecSuccess) {
//			let retrievedData: Data? = dataTypeRef as? Data
//			if let result = NSString(data: retrievedData!, encoding: String.Encoding.utf8.rawValue) {
//				value = result
//			}
//		}
//		else {
//			print("Nothing was retrieved from the keychain. Status code \(status)")
//		}
//		return value as String?
//	}
//
//	private static func setStoredString(_ key: String, value: String) {
//		let dataFromString: Data = value.data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))!;
//		let keychainQuery = NSDictionary(
//			objects: [kSecClassGenericPasswordValue,
//					  key,
//					  dataFromString],
//			forKeys: [kSecClassValue, kSecAttrServiceValue, kSecValueDataValue]);
//		SecItemDelete(keychainQuery as CFDictionary);
//		let _result: OSStatus = SecItemAdd(keychainQuery as CFDictionary, nil);
//		if _result != 0 {
//			print("Storing string in keychain result: \(_result)")
//		}
//	}
}
