//
//  B2CViewController.swift
//  MSALiOS
//
//  Created by Yoel Hor on 7/8/21.
//  Copyright © 2021 Microsoft. All rights reserved.
//

import UIKit
import MSAL

/// 😃 A View Controller that will respond to the events of the Storyboard.

class B2CViewController: UIViewController, UITextFieldDelegate, URLSessionDelegate {
    
    let kTenantName = "fabrikamb2c.onmicrosoft.com" // Your tenant name
    let kAuthorityHostName = "fabrikamb2c.b2clogin.com" // Your authority host name
    let kClientID = "90c0fe63-bcf2-44d5-8fb7-b8bbc0b29dc6" // Your client ID from the portal when you created your application
    let kRedirectUri = "msauth.com.microsoft.identitysample.MSALiOS://auth" // Your application's redirect URI
    let kSignupOrSigninPolicy = "b2c_1_susi" // Your signup and sign-in policy you created in the portal
    let kEditProfilePolicy = "b2c_1_edit_profile" // Your edit policy you created in the portal
    let kResetPasswordPolicy = "b2c_1_reset" // Your reset password policy you created in the portal
    let kGraphURI = "https://fabrikamb2chello.azurewebsites.net/hello" // This is your backend API that you've configured to accept your app's tokens
    let kScopes: [String] = ["https://fabrikamb2c.onmicrosoft.com/helloapi/demo.read"] // This is a scope that you've configured your backend API to look for.
    
    // DO NOT CHANGE - This is the format of OIDC Token and Authorization endpoints for Azure AD B2C.
    let kEndpoint = "https://%@/tfp/%@/%@"
    
    var application: MSALPublicClientApplication!
    
    var accessToken: String?
    
    // UI elements
    var loggingText: UITextView!
    var authorizationButton: UIButton!
    var signOutButton: UIButton!
    var callGraphButton: UIButton!
    var usernameLabel: UILabel!
    var editProfileButton: UIButton!
    var refreshTokenButton: UIButton!
    
    
    override func viewDidLoad() {

        super.viewDidLoad()

        initUI()
        
        do {
            /**
             
             Initialize a MSALPublicClientApplication with a MSALPublicClientApplicationConfig.
             MSALPublicClientApplicationConfig can be initialized with client id, redirect uri and authority.
             */
            
            let siginPolicyAuthority = try self.getAuthority(forPolicy: self.kSignupOrSigninPolicy)
            let editProfileAuthority = try self.getAuthority(forPolicy: self.kEditProfilePolicy)

            // Provide configuration for MSALPublicClientApplication
            // MSAL will use default redirect uri when you provide nil
            let pcaConfig = MSALPublicClientApplicationConfig(clientId: kClientID, redirectUri: kRedirectUri, authority: siginPolicyAuthority)
            pcaConfig.knownAuthorities = [siginPolicyAuthority, editProfileAuthority]
            
            self.application = try MSALPublicClientApplication(configuration: pcaConfig)
        } catch {
            self.updateLoggingText(text: "Unable to create application \(error)")
        }

    }
    
    /**
     This button will invoke the authorization flow and send the policy specified to the B2C server.
     Here we are using the `kSignupOrSignInPolicy` to sign the user in to the app. We will store this
     accessToken for subsequent calls.
     */
    
    @objc func authorizationButton(_ sender: UIButton) {
        do {
            /**
             
             authority is a URL indicating a directory that MSAL can use to obtain tokens. In Azure B2C
             it is of the form `https://<instance/tfp/<tenant>/<policy>`, where `<instance>` is the
             directory host (e.g. https://login.microsoftonline.com), `<tenant>` is a
             identifier within the directory itself (e.g. a domain associated to the
             tenant, such as contoso.onmicrosoft.com), and `<policy>` is the policy you wish to
             use for the current user flow.
             
             */
            
            let authority = try self.getAuthority(forPolicy: self.kSignupOrSigninPolicy)
            
            /**
             Acquire a token for a new account using interactive authentication
             
             - scopes: Permissions you want included in the access token received
             in the result in the completionBlock. Not all scopes are
             gauranteed to be included in the access token returned.
             - completionBlock: The completion block that will be called when the authentication
             flow completes, or encounters an error.
             */
            
            let webViewParameters = MSALWebviewParameters(parentViewController: self)
            let parameters = MSALInteractiveTokenParameters(scopes: kScopes, webviewParameters: webViewParameters)
            parameters.promptType = .selectAccount
            parameters.authority = authority
            //parameters.webviewType = .wkWebView
        
            
            application.acquireToken(with: parameters) { (result, error) in
                
                guard let result = result else {
                    self.updateLoggingText(text: "Could not acquire token: \(error ?? "No error informarion" as! Error)")
                    return
                }
                
                self.accessToken = result.accessToken
                self.updateLoggingText(text: "Access token is \(self.accessToken ?? "Empty")")
                self.signOutButton.isEnabled = true
                self.callGraphButton.isEnabled = true
                self.editProfileButton.isEnabled = true
                self.refreshTokenButton.isEnabled = true
            }
        } catch {
            self.updateLoggingText(text: "Unable to create authority \(error)")
        }
    }
    
    @objc func editProfile(_ sender: UIButton) {
        do {
            
            /**
             
             authority is a URL indicating a directory that MSAL can use to obtain tokens. In Azure B2C
             it is of the form `https://<instance/tfp/<tenant>/<policy>`, where `<instance>` is the
             directory host (e.g. https://login.microsoftonline.com), `<tenant>` is a
             identifier within the directory itself (e.g. a domain associated to the
             tenant, such as contoso.onmicrosoft.com), and `<policy>` is the policy you wish to
             use for the current user flow.
             
             */
            
            let authority = try self.getAuthority(forPolicy: self.kEditProfilePolicy)
            
            /**
             Acquire a token for a new account using interactive authentication
             
             - scopes: Permissions you want included in the access token received
             in the result in the completionBlock. Not all scopes are
             gauranteed to be included in the access token returned.
             - completionBlock: The completion block that will be called when the authentication
             flow completes, or encounters an error.
             */
            
            let thisAccount = try self.getAccountByPolicy(withAccounts: application.allAccounts(), policy: kEditProfilePolicy)
            let webViewParameters = MSALWebviewParameters(parentViewController: self)
            let parameters = MSALInteractiveTokenParameters(scopes: kScopes, webviewParameters: webViewParameters)
            parameters.authority = authority
            parameters.account = thisAccount
            
            application.acquireToken(with: parameters) { (result, error) in
                if let error = error {
                    self.updateLoggingText(text: "Could not edit profile: \(error)")
                } else {
                    self.updateLoggingText(text: "Successfully edited profile")
                }
            }
        } catch {
            self.updateLoggingText(text: "Unable to construct parameters before calling acquire token \(error)")
        }
    }
    
    @objc func refreshToken(_ sender: UIButton) {
        
        do {
            /**
             
             authority is a URL indicating a directory that MSAL can use to obtain tokens. In Azure B2C
             it is of the form `https://<instance/tfp/<tenant>/<policy>`, where `<instance>` is the
             directory host (e.g. https://login.microsoftonline.com), `<tenant>` is a
             identifier within the directory itself (e.g. a domain associated to the
             tenant, such as contoso.onmicrosoft.com), and `<policy>` is the policy you wish to
             use for the current user flow.
             
             */
            
            let authority = try self.getAuthority(forPolicy: self.kSignupOrSigninPolicy)
            
            /**
             
             Acquire a token for an existing account silently
             
             - scopes: Permissions you want included in the access token received
             in the result in the completionBlock. Not all scopes are
             gauranteed to be included in the access token returned.
             - account: An account object that we retrieved from the application object before that the
             authentication flow will be locked down to.
             - completionBlock: The completion block that will be called when the authentication
             flow completes, or encounters an error.
             */
            
            guard let thisAccount = try self.getAccountByPolicy(withAccounts: application.allAccounts(), policy: kSignupOrSigninPolicy) else {
                self.updateLoggingText(text: "There is no account available!")
                return
            }
            
            let parameters = MSALSilentTokenParameters(scopes: kScopes, account:thisAccount)
            parameters.authority = authority
            self.application.acquireTokenSilent(with: parameters) { (result, error) in
                if let error = error {
                    
                    let nsError = error as NSError
                    
                    // interactionRequired means we need to ask the user to sign-in. This usually happens
                    // when the user's Refresh Token is expired or if the user has changed their password
                    // among other possible reasons.
                    
                    if (nsError.domain == MSALErrorDomain) {
                        
                        if (nsError.code == MSALError.interactionRequired.rawValue) {
                            
                            // Notice we supply the account here. This ensures we acquire token for the same account
                            // as we originally authenticated.
                            
                            let webviewParameters = MSALWebviewParameters(parentViewController: self)
                            let parameters = MSALInteractiveTokenParameters(scopes: self.kScopes, webviewParameters: webviewParameters)
                            parameters.account = thisAccount
                            
                            self.application.acquireToken(with: parameters) { (result, error) in
                                
                                guard let result = result else {
                                    self.updateLoggingText(text: "Could not acquire new token: \(error ?? "No error informarion" as! Error)")
                                    return
                                }
                                
                                self.accessToken = result.accessToken
                                self.updateLoggingText(text: "Access token is \(self.accessToken ?? "empty")")
                            }
                            return
                        }
                    }
                    
                    self.updateLoggingText(text: "Could not acquire token: \(error)")
                    return
                }
                
                guard let result = result else {
                    
                    self.updateLoggingText(text: "Could not acquire token: No result returned")
                    return
                }
                
                self.accessToken = result.accessToken
                self.updateLoggingText(text: "Refreshing token silently")
                self.updateLoggingText(text: "Refreshed access token is \(self.accessToken ?? "empty")")
            }
        } catch {
            self.updateLoggingText(text: "Unable to construct parameters before calling acquire token \(error)")
        }
    }
    
    @objc func callGraphAPI(_ sender: UIButton) {
        guard let accessToken = self.accessToken else {
            self.updateLoggingText(text: "Operation failed because could not find an access token!")
            return
        }
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30
        let url = URL(string: self.kGraphURI)
        var request = URLRequest(url: url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let urlSession = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: OperationQueue.main)
        
        self.updateLoggingText(text: "Calling the API....")
        
        urlSession.dataTask(with: request) { data, response, error in
            guard let validData = data else {
                self.updateLoggingText(text: "Could not call API: \(error ?? "No error informarion" as! Error)")
                return
            }
            
            let result = try? JSONSerialization.jsonObject(with: validData, options: [])
            
            guard let validResult = result as? [String: Any] else {
                self.updateLoggingText(text: "Nothing returned from API")
                return
            }
            
            self.updateLoggingText(text: "API response: \(validResult.debugDescription)")
            }.resume()
    }
    
    @objc func signoutButton(_ sender: UIButton) {
        do {
            /**
             Removes all tokens from the cache for this application for the provided account
             
             - account:    The account to remove from the cache
             */
            
            let thisAccount = try self.getAccountByPolicy(withAccounts: application.allAccounts(), policy: kSignupOrSigninPolicy)
            
            if let accountToRemove = thisAccount {
                try application.remove(accountToRemove)
            } else {
                self.updateLoggingText(text: "There is no account to signing out!")
            }
            
            self.signOutButton.isEnabled = false
            self.callGraphButton.isEnabled = false
            self.editProfileButton.isEnabled = false
            self.refreshTokenButton.isEnabled = false
            
            self.updateLoggingText(text: "Signed out")
            
        } catch  {
            self.updateLoggingText(text: "Received error signing out: \(error)")
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        if self.accessToken == nil {
            signOutButton.isEnabled = false
            callGraphButton.isEnabled = false
            editProfileButton.isEnabled = false
            refreshTokenButton.isEnabled = false
        }
    }
    
    func getAccountByPolicy (withAccounts accounts: [MSALAccount], policy: String) throws -> MSALAccount? {
        
        for account in accounts {
            // This is a single account sample, so we only check the suffic part of the object id,
            // where object id is in the form of <object id>-<policy>.
            // For multi-account apps, the whole object id needs to be checked.
            if let homeAccountId = account.homeAccountId, let objectId = homeAccountId.objectId {
                if objectId.hasSuffix(policy.lowercased()) {
                    return account
                }
            }
        }
        return nil
    }
    
    /**
     
     The way B2C knows what actions to perform for the user of the app is through the use of `Authority URL`.
     It is of the form `https://<instance/tfp/<tenant>/<policy>`, where `<instance>` is the
     directory host (e.g. https://login.microsoftonline.com), `<tenant>` is a
     identifier within the directory itself (e.g. a domain associated to the
     tenant, such as contoso.onmicrosoft.com), and `<policy>` is the policy you wish to
     use for the current user flow.
     */
    func getAuthority(forPolicy policy: String) throws -> MSALB2CAuthority {
        guard let authorityURL = URL(string: String(format: self.kEndpoint, self.kAuthorityHostName, self.kTenantName, policy)) else {
            throw NSError(domain: "SomeDomain",
                          code: 1,
                          userInfo: ["errorDescription": "Unable to create authority URL!"])
        }
        return try MSALB2CAuthority(url: authorityURL)
    }
    
    func updateLoggingText(text: String) {
        DispatchQueue.main.async{
            self.loggingText.text = text
        }
    }
}



// Yoel: UI Helpers
extension B2CViewController {
    
    func initUI() {
        
        usernameLabel = UILabel()
        usernameLabel.translatesAutoresizingMaskIntoConstraints = false
        usernameLabel.text = ""
        usernameLabel.textColor = .darkGray
        usernameLabel.textAlignment = .right
        
        self.view.addSubview(usernameLabel)
        
        usernameLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 50.0).isActive = true
        usernameLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -10.0).isActive = true
        usernameLabel.widthAnchor.constraint(equalToConstant: 300.0).isActive = true
        usernameLabel.heightAnchor.constraint(equalToConstant: 50.0).isActive = true
        
        // Add authorizationButton button
        authorizationButton  = UIButton()
        authorizationButton.translatesAutoresizingMaskIntoConstraints = false
        authorizationButton.setTitle("Sign In", for: .normal)
        authorizationButton.setTitleColor(.blue, for: .normal)
        authorizationButton.addTarget(self, action: #selector(authorizationButton(_:)), for: .touchUpInside)
        
        self.view.addSubview(authorizationButton)
        
        authorizationButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        authorizationButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 80.0).isActive = true
        authorizationButton.widthAnchor.constraint(equalToConstant: 300.0).isActive = true
        authorizationButton.heightAnchor.constraint(equalToConstant: 50.0).isActive = true
        
        // Add call Graph button
        callGraphButton  = UIButton()
        callGraphButton.translatesAutoresizingMaskIntoConstraints = false
        callGraphButton.setTitle("Call a Graph API", for: .normal)
        callGraphButton.setTitleColor(.blue, for: .normal)
        callGraphButton.setTitleColor(.gray, for: .disabled)
        callGraphButton.addTarget(self, action: #selector(callGraphAPI(_:)), for: .touchUpInside)
        self.view.addSubview(callGraphButton)
        
        callGraphButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        callGraphButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 120.0).isActive = true
        callGraphButton.widthAnchor.constraint(equalToConstant: 300.0).isActive = true
        callGraphButton.heightAnchor.constraint(equalToConstant: 50.0).isActive = true
        
        // Add sign out button
        signOutButton = UIButton()
        signOutButton.translatesAutoresizingMaskIntoConstraints = false
        signOutButton.setTitle("Sign Out", for: .normal)
        signOutButton.setTitleColor(.blue, for: .normal)
        signOutButton.setTitleColor(.gray, for: .disabled)
        signOutButton.addTarget(self, action: #selector(signoutButton(_:)), for: .touchUpInside)
        self.view.addSubview(signOutButton)
        
        signOutButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        signOutButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 160.0).isActive = true
        signOutButton.widthAnchor.constraint(equalToConstant: 150.0).isActive = true
        signOutButton.heightAnchor.constraint(equalToConstant: 50.0).isActive = true
                
        
        // Add refreshTokenButton button
        refreshTokenButton  = UIButton()
        refreshTokenButton.translatesAutoresizingMaskIntoConstraints = false
        refreshTokenButton.setTitle("Refrsh token", for: .normal)
        refreshTokenButton.setTitleColor(.blue, for: .normal)
        refreshTokenButton.setTitleColor(.gray, for: .disabled)
        refreshTokenButton.addTarget(self, action: #selector(refreshToken(_:)), for: .touchUpInside)
        self.view.addSubview(refreshTokenButton)
        
        refreshTokenButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        refreshTokenButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 200.0).isActive = true
        refreshTokenButton.widthAnchor.constraint(equalToConstant: 300.0).isActive = true
        refreshTokenButton.heightAnchor.constraint(equalToConstant: 50.0).isActive = true
        
        // Add editProfileButton button
        editProfileButton  = UIButton()
        editProfileButton.translatesAutoresizingMaskIntoConstraints = false
        editProfileButton.setTitle("Edit profile", for: .normal)
        editProfileButton.setTitleColor(.blue, for: .normal)
        editProfileButton.setTitleColor(.gray, for: .disabled)
        editProfileButton.addTarget(self, action: #selector(editProfile(_:)), for: .touchUpInside)
        self.view.addSubview(editProfileButton)
        
        editProfileButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        editProfileButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 240.0).isActive = true
        editProfileButton.widthAnchor.constraint(equalToConstant: 300.0).isActive = true
        editProfileButton.heightAnchor.constraint(equalToConstant: 50.0).isActive = true
        
        // Add logging textfield
        loggingText = UITextView()
        loggingText.isUserInteractionEnabled = false
        loggingText.translatesAutoresizingMaskIntoConstraints = false
        
        self.view.addSubview(loggingText)
        
        loggingText.topAnchor.constraint(equalTo: editProfileButton.bottomAnchor, constant: 10.0).isActive = true
        loggingText.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: 10.0).isActive = true
        loggingText.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: -10.0).isActive = true
        loggingText.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: 10.0).isActive = true
    }
}
