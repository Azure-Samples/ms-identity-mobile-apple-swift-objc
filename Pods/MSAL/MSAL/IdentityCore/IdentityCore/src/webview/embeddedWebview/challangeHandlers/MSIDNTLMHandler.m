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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <WebKit/WebKit.h>
#import "MSIDNTLMHandler.h"
#import "MSIDChallengeHandler.h"
#import "MSIDNTLMUIPrompt.h"

@implementation MSIDNTLMHandler

+ (void)load
{
    [MSIDChallengeHandler registerHandler:self
                               authMethod:NSURLAuthenticationMethodNTLM];
}

+ (void)resetHandler
{
    @synchronized(self)
    {
        [MSIDNTLMUIPrompt dismissPrompt];
    }
}

+ (BOOL)handleChallenge:(NSURLAuthenticationChallenge *)challenge
                webview:(__unused WKWebView *)webview
                context:(id<MSIDRequestContext>)context
      completionHandler:(ChallengeCompletionHandler)completionHandler
{
    @synchronized(self)
    {
        // This is the NTLM challenge: use the identity to authenticate:
        
        MSID_LOG_NO_PII(MSIDLogLevelInfo, nil, context, @"Attempting to handle NTLM challenge");
        MSID_LOG_PII(MSIDLogLevelInfo, nil, context, @"Attempting to handle NTLM challenge host: %@", challenge.protectionSpace.host);
        
        [MSIDNTLMUIPrompt presentPrompt:^(NSString *username, NSString *password, BOOL cancel)
         {
             if (cancel)
             {
                 MSID_LOG_NO_PII(MSIDLogLevelInfo, nil, context, @"NTLM challenge cancelled");
                 MSID_LOG_PII(MSIDLogLevelInfo, nil, context, @"NTLM challenge cancelled - host: %@", challenge.protectionSpace.host);
                 
                 completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
             }
             else
             {
                 NSURLCredential *credential = [NSURLCredential credentialWithUser:username
                                                                          password:password
                                                                       persistence:NSURLCredentialPersistenceForSession];
                 
                 completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
                 
                 MSID_LOG_NO_PII(MSIDLogLevelInfo, nil, context, @"NTLM credentials added");
                 MSID_LOG_PII(MSIDLogLevelInfo, nil, context, @"NTLM credentials added - host: %@", challenge.protectionSpace.host);
             }
         }];
    }//@synchronized
    
    return YES;
}

@end
