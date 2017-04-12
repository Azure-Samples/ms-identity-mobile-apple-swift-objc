//
//  ViewController.swift
//  MSALiOS
//
//  Created by Brandon Werner on 4/8/17.
//  Copyright © 2017 Microsoft. All rights reserved.
//

import UIKit
import MSAL

let kIssuer = "https://login.microsoftonline.com/brandwedir.onmicrosoft.com/v2.0"
let kClientID = "2a814505-ab4a-41f7-bd09-3fc614ac077c"
let kRedirectURI = "msal://com.xerners/"
let kLogoutURI = "https://login.microsoftonline.com/common/oauth2/v2.0/logout"
let kScopes: [String] = ["https://graph.microsoft.com/mail.read"]
let kAuthority = "https://login.microsoftonline.com/common/oauth2/v2.0/authorize"

class ViewController: UIViewController, UITextFieldDelegate {

    @IBAction func authorizationButton(_ sender: UIButton) {
        
        
        if let application = try? MSALPublicClientApplication.init(clientId: kClientID, authority: kAuthority) {

        application.acquireToken(forScopes: kScopes) { (result, error) in
            if result != nil {
                self.loggingText.text = result?.accessToken;
            } else {
                print("Error received");
            }
        }
    }
        
        else {
            self.loggingText.text = "unable to create application."
        }
}


    @IBAction func signoutButton(_ sender: UIButton) {
    }
    
    @IBOutlet weak var loggingText: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
        


}

