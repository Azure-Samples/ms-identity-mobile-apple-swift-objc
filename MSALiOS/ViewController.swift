//------------------------------------------------------------------------------
//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

import UIKit
import MSAL

let kIssuer = "https://login.microsoftonline.com/brandwedir.onmicrosoft.com/v2.0"
let kClientID = "2a814505-ab4a-41f7-bd09-3fc614ac077c"
let kRedirectURI = "msal://com.xerners/"
let kLogoutURI = "https://login.microsoftonline.com/common/oauth2/v2.0/logout"
let kGraphURI = "https://graph.microsoft.com/v1.0/me/"
let kScopes: [String] = ["https://graph.microsoft.com/user.read"]
let kAuthority = "https://login.microsoftonline.com/common/oauth2/v2.0/authorize"



struct User {
    
    var user = MSALUser.init()
}

class ViewController: UIViewController, UITextFieldDelegate, URLSessionDelegate {
    
var msalResult =  MSALResult.init()

    
@IBOutlet weak var loggingText: UITextView!
@IBOutlet weak var signoutButton: UIButton!
@IBOutlet weak var callGraphApiButton: UIButton!
@IBOutlet weak var silentRefreshButton: UIButton!
    
    
    /**
     This button will invoke the authorization flow.
    */

@IBAction func authorizationButton(_ sender: UIButton) {
    
    /*!
     Initialize a MSALPublicClientApplication with a given clientID and authority
     
     @param  AClientID    The clientID of your application, you should get this from the app portal.
     @param  kAuthority   A URL indicating a directory that MSAL can use to obtain tokens. In Azure AD
     it is of the form https://<instance/<tenant>, where <instance> is the
     directory host (e.g. https://login.microsoftonline.com) and <tenant> is a
     identifier within the directory itself (e.g. a domain associated to the
     tenant, such as contoso.onmicrosoft.com, or the GUID representing the
     TenantID property of the directory)
     @param  error       The error that occurred creating the application object, if any, if you're
     not interested in the specific error pass in nil.
     */

    
    do {
        let application = try MSALPublicClientApplication.init(clientId: kClientID, authority: kAuthority)
    
            /*!
             Acquire a token for a new user using interactive authentication
             
             @param  kScopes Permissions you want included in the access token received
             in the result in the completionBlock. Not all scopes are
             gauranteed to be included in the access token returned.
             @param  completionBlock The completion block that will be called when the authentication
             flow completes, or encounters an error.
             */
        application.acquireToken(forScopes: kScopes) { (result, error) in
            DispatchQueue.main.async {
            if result != nil {
                self.msalResult = result!
                self.loggingText.text = "Access token is \(self.msalResult.accessToken!)"
                self.signoutButton.isEnabled = true;
                self.callGraphApiButton.isEnabled = true;
                self.silentRefreshButton.isEnabled = true;
                
                
            } else {
                self.loggingText.text = "Could not acquire token: \(error?.localizedDescription ?? "No Error provided")"
            }
        }
            }
    }
        
        catch {
                        self.loggingText.text = "Unable to create application \(error)"
        }
}
    
    /**
     This button will invoke the call to the Microsoft Graph API. It uses the built in Swift libraries to create a connection.
     */

@IBAction func callGraphApi(_ sender: UIButton) {
    
    let sessionConfig = URLSessionConfiguration.default
    
    // Specify the Graph API endpoint
    let url = URL(string: kGraphURI)
    var request = URLRequest(url: url!)
    
    // Set the Authorization header for the request. We use Bearer tokens, so we specify Bearer + the token we got from the result
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
    /**
     This button will invoke the signout APIs to clear the token cache.
     */
    @IBAction func silentRefreshButton(_ sender: UIButton) {
        
        do {
            let application = try MSALPublicClientApplication.init(clientId: kClientID, authority: kAuthority)
            
            /*!
             Acquire a token for a new user using interactive authentication
             
             @param  kScopes Permissions you want included in the access token received
             in the result in the completionBlock. Not all scopes are
             gauranteed to be included in the access token returned.
             @param  completionBlock The completion block that will be called when the authentication
             flow completes, or encounters an error.
             */
            application.acquireTokenSilent(forScopes: kScopes, user: msalResult.user) { (result, error) in
                DispatchQueue.main.async {
                    if result != nil {
                        self.msalResult = result!
                        self.loggingText.text = "Refreshing token silently)"
                        self.loggingText.text = "Refreshed Access token is \(self.msalResult.accessToken!)"
                        self.signoutButton.isEnabled = true;
                        self.callGraphApiButton.isEnabled = true;
                        self.silentRefreshButton.isEnabled = true;
                        
                        
                    } else {
                        self.loggingText.text = "Could not acquire token: \(error?.localizedDescription ?? "No Error provided")"
                    }
                }
        }
        }
    
        catch {
            self.loggingText.text = "Unable to create application \(error)"
            
        }
        
        
    }
    /**
     This button will invoke the signout APIs to clear the token cache.
     */

@IBAction func signoutButton(_ sender: UIButton) {
    
    if let application = try? MSALPublicClientApplication.init(clientId: kClientID, authority: kAuthority) {
        
        DispatchQueue.main.async {
        do {
            try application.remove(self.msalResult.user)
            self.signoutButton.isEnabled = false;
            self.callGraphApiButton.isEnabled = false;
            self.silentRefreshButton.isEnabled = false;
            
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
            silentRefreshButton.isEnabled = false;
            
            
        }
    }
    
        


}

