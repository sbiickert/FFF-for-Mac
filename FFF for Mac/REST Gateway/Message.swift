//
//  Message.swift
//  FFFMobile
//
//  Created by Simon Biickert on 2016-07-15.
//  Copyright © 2016 Simon Biickert. All rights reserved.
//

import Foundation

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
