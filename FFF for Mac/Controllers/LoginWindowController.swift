//
//  LoginWindowController.swift
//  FFF for Mac
//
//  Created by Simon Biickert on 2018-02-19.
//  Copyright © 2018 ii Softwerks. All rights reserved.
//

import Cocoa

class LoginWindowController: NSWindowController, NSTextFieldDelegate {

	@IBOutlet weak var usernameTextField: NSTextField!
	@IBOutlet weak var passwordTextField: NSSecureTextField!
	@IBOutlet weak var okButton: NSButton!
	@IBOutlet weak var quitButton: NSButton!
	@IBOutlet weak var spinner: NSProgressIndicator!
	
	@IBAction func textChanged(_ sender: NSTextField) {
		enableOKButton()
	}
	
	@IBAction func submit(_ sender: Any) {
		spinner.startAnimation(self)
		self.window?.sheetParent?.endSheet(self.window!)
	}
	
	@IBAction func quit(_ sender: Any) {
		self.window?.sheetParent?.endSheet(self.window!, returnCode: .abort)
		NSApp.terminate(self)
	}
	
	func controlTextDidChange(_ obj: Notification) {
		enableOKButton()
	}
	
	private func enableOKButton() {
		// Check that text exists in both inputs
		okButton.isEnabled = usernameTextField.stringValue.count > 0 && passwordTextField.stringValue.count > 0

	}
	
	override func windowDidLoad() {
        super.windowDidLoad()
		
		self.usernameTextField.delegate = self
		self.passwordTextField.delegate = self
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
		
		// http://www.knowstack.com/swift-nsdatepicker-sample-code-2-using-beginsheet/
    }
}
