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


#import "ViewController.h"
#import <MSAL/MSAL.h>

/// 😃 A View Controller that will respond to the events of the Storyboard.

@interface ViewController ()
    
    @end

@implementation ViewController
    
    MSALPublicClientApplication *application;
    
    // Update the below to your client ID you received in the portal. The below is for running the demo only
    NSString *clientId = @"db9191e7-9fa9-41e5-84e6-223298a0e9b2";
    // Additional variables for Auth and Graph API
    NSString *redirectUri = @"msaldb9191e7-9fa9-41e5-84e6-223298a0e9b2://auth";
    NSString *authorityString = @"https://login.microsoftonline.com/common";
    NSString *graphURI = @"https://graph.microsoft.com/v1.0/me/";
    
    /**
     Setup public client application in viewDidLoad
     */
    
    - (void)viewDidLoad {
        [super viewDidLoad];
        // Do any additional setup after loading the view.
        [self initMSAL];
    }
    
    // MARK: Initialization

    -(void) initMSAL{
        
        /**
         
         Initialize a MSALPublicClientApplication with a given clientID and authority
         
         - clientId:            The clientID of your application, you should get this from the app portal.
         - redirectUri:         A redirect URI of your application, you should get this from the app portal.
         If nil, MSAL will create one by default. i.e./ msauth.<bundleID>://auth
         - authority:           A URL indicating a directory that MSAL can use to obtain tokens. In Azure AD
         it is of the form https://<instance/<tenant>, where <instance> is the
         directory host (e.g. https://login.microsoftonline.com) and <tenant> is a
         identifier within the directory itself (e.g. a domain associated to the
         tenant, such as contoso.onmicrosoft.com, or the GUID representing the
         TenantID property of the directory)
         - error                The error that occurred creating the application object, if any, if you're
         not interested in the specific error pass in nil.
         */
        
        NSError *error = nil;
        
        NSURL *authorityURL = [NSURL URLWithString:(authorityString)];
        
        MSALAuthority *authority = [MSALAuthority authorityWithURL:authorityURL error:nil];
        
        
        MSALPublicClientApplicationConfig *pcaConfig = [[MSALPublicClientApplicationConfig alloc] initWithClientId:clientId
                                                                                                       redirectUri:redirectUri
                                                                                                         authority:authority];
        
        application = [[MSALPublicClientApplication alloc] initWithConfiguration:pcaConfig error:&error];
        
        if (application == nil)
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error initializing application"
                                                            message:error.description
                                                           delegate:self
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            
            return;
        }
    }
    
    - (void)didReceiveMemoryWarning{
        [super didReceiveMemoryWarning];
    }
    
    /**
     This action will invoke the remove account APIs to clear the token cache
     to sign out a user from this application.
     */
    
    - (IBAction)signOut{
        
        MSALAccount *account = [self currentAccount];
        if (account == nil){
            return;
        }
        
        /**
         Removes all tokens from the cache for this application for the provided account
         
         - account:    The account to remove from the cache
         */
        
        [application removeAccount:account error:nil];
        _signout.enabled = false;
        [_resultTextView setText:@""];
    }
    
    // MARK: Acquiring and using token
    
    /**
     This will invoke the authorization flow.
     */
    
    - (IBAction)callGraphAction: (id)sender{
        
        MSALAccount *msalAccount = [self currentAccount];
        // We check to see if we have a current logged in account.
        // If we don't, then we need to sign someone in.
        if (msalAccount == nil){
            [self acquireTokenInteractively];
            return;
        }
        
        [self acquireTokenSilently:msalAccount];
    }
    
    -(void)acquireTokenSilently: (MSALAccount*) account {
        /**
         
         Acquire a token for an existing account silently
         
         - forScopes:           Permissions you want included in the access token received
         in the result in the completionBlock. Not all scopes are
         guaranteed to be included in the access token returned.
         - account:             An account object that we retrieved from the application object before that the
         authentication flow will be locked down to.
         - completionBlock:     The completion block that will be called when the authentication
         flow completes, or encounters an error.
         */
        NSArray *scopes = @[@"https://graph.microsoft.com/user.read"];
        
        MSALSilentTokenParameters *parameters = [[MSALSilentTokenParameters alloc] initWithScopes:scopes account:account];
        
        // interactionRequired means we need to ask the user to sign-in. This usually happens
        // when the user's Refresh Token is expired or if the user has changed their password
        // among other possible reasons.
        
        [application acquireTokenSilentWithParameters:parameters completionBlock:^(MSALResult *result, NSError *error)
         {
             if (error != nil){
                 if (error.domain == MSALErrorDomain) {
                     if (error.code == MSALErrorInteractionRequired){
                         dispatch_async(dispatch_get_main_queue(), ^{
                             [self acquireTokenInteractively];
                             return;
                         });
                     }
                 }
             }
             
             [self updateResultView:result];
             dispatch_async(dispatch_get_main_queue(), ^{
                 _signout.enabled = true ;
             });
             [self contentWithToken:[result accessToken]];
         }];
        
    }
    
    -(void)acquireTokenInteractively{
        NSArray *scopes = @[@"https://graph.microsoft.com/user.read"];
        MSALInteractiveTokenParameters *parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:scopes];
        
        
        void (^completionBlock)(MSALResult *result, NSError *error) = ^(MSALResult *result, NSError *error) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                if (result)
                {
                    [self updateResultView:result];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        _signout.enabled = true ;
                    });
                    [self contentWithToken:[result accessToken]];
                }
                else
                {
                    [self updateResultViewError:error];
                }
                
            });
        };
        
        [application acquireTokenWithParameters:parameters completionBlock:completionBlock];
    }
    
    /**
     This will invoke the call to the Microsoft Graph API. It uses the
     built in URLSession to create a connection.
     */
    
    -(void) contentWithToken:(NSString *)token{
        
        // Specify the Graph API endpoint
        NSURL *graphURL = [NSURL URLWithString:(graphURI)];
        NSMutableURLRequest *graphRequest = [NSMutableURLRequest requestWithURL:graphURL];
        NSString *authValue = [NSString stringWithFormat:@"Bearer %@", token];
        // Set the Authorization header for the request. We use Bearer tokens, so we specify Bearer + the token we got from the result
        [graphRequest addValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];
        
        
        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:graphRequest
                                                    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                        NSLog(@"%@",data);
                                                        if (error)
                                                        [self updateResultViewError:error];
                                                        else {
                                                            NSDictionary *json  = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                                                            NSLog(@"%@",json);
                                                            dispatch_async(dispatch_get_main_queue(), ^{
                                                                [self.resultTextView setText:[json description]];
                                                            });
                                                        }
                                                    }];
        [dataTask resume];
        
    }
    
    -(void) updateResultView: (MSALResult*) result{
        NSString *resultText = [NSString stringWithFormat:@"{\n\taccessToken = %@\n\texpiresOn = %@\n\ttenantId = %@\n\tuser = %@\n\tscopes = %@\n\tauthority = %@\n}",
                                result.accessToken, result.expiresOn, result.tenantProfile.tenantId, result.account, result.scopes, result.authority];
        [_resultTextView setText:resultText];
        
    }
    
    -(void) updateResultViewError: (NSError*) error{
        NSString *resultErrorText = [NSString stringWithFormat:@"%@", error];
        [_resultTextView setText:resultErrorText];
    }
    
    // MARK: Get account and removing cache
    
    -(MSALAccount*) currentAccount{
        NSArray<MSALAccount *> *accounts = [application allAccounts:nil];
        // We retrieve our current account by getting the first account from cache
        // In multi-account applications, account should be retrieved by home account identifier or username instead
        return [accounts firstObject];
    }
    
    
    @end
