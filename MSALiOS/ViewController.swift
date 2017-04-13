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
let kGraphURI = "https://graph.microsoft.com/v1.0/me/"
let kScopes: [String] = ["https://graph.microsoft.com/user.read"]
let kAuthority = "https://login.microsoftonline.com/common/oauth2/v2.0/authorize"


class ViewController: UIViewController, UITextFieldDelegate, URLSessionDelegate {
    
var msalResult =  MSALResult.init()
    
@IBOutlet weak var loggingText: UITextView!
@IBOutlet weak var signoutButton: UIButton!
@IBOutlet weak var callGraphApiButton: UIButton!

@IBAction func authorizationButton(_ sender: UIButton) {
        
        
        if let application = try? MSALPublicClientApplication.init(clientId: kClientID, authority: kAuthority) {

        application.acquireToken(forScopes: kScopes) { (result, error) in
            DispatchQueue.main.async {
            if result != nil {
                self.msalResult = result!
                self.loggingText.text = "Access token is \(self.msalResult.accessToken!)"
                self.signoutButton.isEnabled = true;
                self.callGraphApiButton.isEnabled = true;
                
                
            } else {
                self.loggingText.text = "Could not create Public Client instance: \(error?.localizedDescription ?? "No Error provided")"
            }
        }
            }
    }
        
        else {
            self.loggingText.text = "Unable to create application."
        }
}

@IBAction func callGraphApi(_ sender: UIButton) {
    
    let sessionConfig = URLSessionConfiguration.default
    let url = URL(string: kGraphURI)
    var request = URLRequest(url: url!)
    request.setValue("Bearer \(msalResult.accessToken!)", forHTTPHeaderField: "Authorization")
    let urlSession = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: OperationQueue.main)
    
    urlSession.dataTask(with: request) { data, response, error in
        
        let result = try? JSONSerialization.jsonObject(with: data!, options: [])
        DispatchQueue.main.async {
            if result != nil {
                
                self.loggingText.text = result.debugDescription
                

            }
        }
        }.resume()
}

@IBAction func signoutButton(_ sender: UIButton) {
    
    if let application = try? MSALPublicClientApplication.init(clientId: kClientID, authority: kAuthority) {
        
        DispatchQueue.main.async {
        do {
            try application.remove(self.msalResult.user)
            self.signoutButton.isEnabled = false;
            self.callGraphApiButton.isEnabled = false;
            
        } catch let error {
            self.loggingText.text = "Received error signing user out: \(error.localizedDescription)"
                        }
        }
    }
    
}
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        if self.msalResult.accessToken == nil {
            
            signoutButton.isEnabled = false;
            callGraphApiButton.isEnabled = false;
            
            
        }
    }
    
        


}

