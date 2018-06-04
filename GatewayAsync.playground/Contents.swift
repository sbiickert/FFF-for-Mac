//: Playground - noun: a place where people can play

import Foundation
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true
let APP_ERROR_DOMAIN = "ca.biickert.fff.ErrorDomain"

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

class Message: NSObject {
    var content: NSDictionary
    var url: String
    var isError: Bool
    var code: Int
    
    init(dictionary: NSDictionary) {
        // Is this an error? Has key "message": NO. Has key "error": YES
        let errorInfo = dictionary.object(forKey: ResponseKey.Error.rawValue)
        let messageInfo = dictionary.object(forKey: ResponseKey.Message.rawValue)
        
        if (errorInfo != nil)
        {
            self.isError = true
            content = errorInfo as! NSDictionary
        }
        else // if (messageInfo != nil)
        {
            self.isError = false;
            content = messageInfo as! NSDictionary
        }
        
        self.url = self.content[ResponseKey.Url.rawValue] as! String
        self.code = content[ResponseKey.Code.rawValue] as! Int
    }
}

class Gateway {
    static let shared = Gateway()
    static let url = "http://localhost/FFF/services/web"
    
    var userName: String?
    var password: String?

    var session: URLSession?
    var token: String?

    private init() {
        let config = URLSessionConfiguration.default
        session = Foundation.URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        
        userName = "sjb"
        password = "boo2u"
    }
    
    // MARK: Public API
    func login() {
        retrieveToken()
    }
    
    func logout() {
        self.token = nil;
    }
    
    func getTransaction(withID id:Int, callback: @escaping (String) -> Void) {
        let fullUrl = String(format: "%@/%@/%@/json?token=%@", Gateway.url, RestResource.TransactionResource.rawValue, String(id), self.token!)
        print("Fetching transaction: \(fullUrl)");
        
        let request = NSMutableURLRequest(url: URL(string: fullUrl)!)
        processRequest(request as URLRequest) {info in
            print("callback")
            let success = (info[ResponseKey.Success.rawValue] as! NSNumber).boolValue
            if (success) {
                let message = info[ResponseKey.Message.rawValue] as! Message
                callback(message.content.description)
            }
        }
    }

    // MARK: Private implementation
    
    private func retrieveToken() {
        let fullUrl = String(format: "%@/%@/%@/json?p=%@", Gateway.url, RestResource.TokenResource.rawValue, userName!, password!)
        print("Fetching token: \(fullUrl)");
        
        let request = NSMutableURLRequest(url: URL(string: fullUrl)!)
        processRequest(request as URLRequest) {[weak self] info in
            print("callback")
            let success = (info[ResponseKey.Success.rawValue] as! NSNumber).boolValue
            if (success) {
                let message = info[ResponseKey.Message.rawValue] as! Message
                
                //let content = message.content[ResponseKey.Message.rawValue] as! NSDictionary
                let tokenInfo = message.content[ResponseKey.Token.rawValue] as! NSDictionary
                print(tokenInfo[ResponseKey.FullName.rawValue] as! String)
                self?.token = tokenInfo[ResponseKey.Key.rawValue] as? String
                print("Fetched a key: \(String(describing: self?.token))");
                nextStep()
            }
        }
    }
    
    private func processRequest(_ request: URLRequest, closure: @escaping (_ info: NSDictionary) -> Void) {
        var info = NSDictionary()
        print("processRequest")
        let task = session?.dataTask(with: request, completionHandler: {(data: Data?, response: URLResponse?, error: Error?) -> Void in
            print("completionHandler")
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
    
    private func convertNSDictionary(_ nsDict:NSDictionary) -> [String: Any] {
        var dict = [String: Any]()
        for key in nsDict.allKeys {
            let sKey = String(describing:key)
            dict[sKey] = nsDict[key]
        }
        return dict
    }

}

func nextStep() {
    print(Gateway.shared.token!)
    Gateway.shared.getTransaction(withID: 6362) { info in
        print(info)
    }
}

Gateway.shared.login()

