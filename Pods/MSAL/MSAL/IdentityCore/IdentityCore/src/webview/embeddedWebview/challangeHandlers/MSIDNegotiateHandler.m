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

#import "MSIDNegotiateHandler.h"
#import "MSIDChallengeHandler.h"
#include <GSS/GSS.h>

@implementation MSIDNegotiateHandler

+ (void)load
{
    [MSIDChallengeHandler registerHandler:self authMethod:NSURLAuthenticationMethodNegotiate];
}

+ (void)resetHandler { }

+ (BOOL)handleChallenge:(NSURLAuthenticationChallenge *)challenge
                webview:(__unused WKWebView *)webview
                context:(id<MSIDRequestContext>)context
      completionHandler:(ChallengeCompletionHandler)completionHandler
{
#pragma unused(challenge)
    
    if ([self hasValidKBRCredential:context])
    {
        // This means we have an unexpired credential, let system handle it
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Perform default system handling for Negotiate");
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
    else
    {
        // This challenge is rejected and the next authentication protection space should be tried by OS
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Reject protection space, so the next one can be tried");
        completionHandler(NSURLSessionAuthChallengeRejectProtectionSpace, nil);
    }
    
    return YES;
}

#pragma mark - Credential checking

+ (BOOL)hasValidKBRCredential:(id<MSIDRequestContext>)context
{
    OM_uint32 minor;
    
    __block BOOL foundUnexpiredKBRCredential = NO;
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Checking credentials to handle Negotiate challenge");
    
    // Go over all credentials that can be found
    gss_iter_creds(&minor, 0, GSS_KRB5_MECHANISM,
                   ^(__unused gss_iter_OID mechOid, gss_cred_id_t credential) {
                       
                       if (credential == GSS_C_NO_CREDENTIAL)
                       {
                           MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"No more credentials found for GSS_KRB5_MECHANISM");
                           return;
                       }
                       
                       MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Found a credential, now check its validity...");
                       
                       // Copy the name describing the credential
                       gss_name_t credentialName = GSSCredentialCopyName(credential);
                       
                       if (credentialName != GSS_C_NO_NAME)
                       {
                           CFStringRef displayableName = GSSNameCreateDisplayString(credentialName);
                           
                           // Get the lifetime of this credential
                           uint32_t lifeTime = GSSCredentialGetLifetime(credential);
                           
                           MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, context, @"Found credential for GSS_KRB5_MECHANISM with lifetime %d, displayable name %@", lifeTime, MSID_PII_LOG_EMAIL((__bridge id _Nonnull)(displayableName)));
                           
                           if (displayableName)
                           {
                               CFRelease(displayableName);
                           }
                           
                           // Found an unexpired credential
                           if (lifeTime > 0)
                           {
                               MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Found unexpired credential");
                               
                               foundUnexpiredKBRCredential = YES;
                               releaseCredential(&credential);
                               releaseName(&credentialName);
                               return;
                           }
                       }
                       else
                       {
                           MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"Failed to get credential name, skip");
                       }
                       
                       releaseName(&credentialName);
                       releaseCredential(&credential);
                   });
    
    return foundUnexpiredKBRCredential;
}

#pragma mark - Helpers

static void releaseCredential(gss_cred_id_t *credential)
{
    if (credential && *credential != GSS_C_NO_CREDENTIAL)
    {
        OM_uint32 minorStatus;
        gss_release_cred(&minorStatus, credential);
        *credential = GSS_C_NO_CREDENTIAL;
    }
}

static void releaseName(gss_name_t *name)
{
    if (name && *name != GSS_C_NO_NAME)
    {
        OM_uint32 minorStatus;
        gss_release_name(&minorStatus, name);
        *name = GSS_C_NO_NAME;
    }
}

@end
