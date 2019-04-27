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

#import "MSIDLegacyTokenResponseValidator.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDTokenResult.h"
#import "MSIDAccount.h"

@implementation MSIDLegacyTokenResponseValidator

- (BOOL)validateTokenResult:(MSIDTokenResult *)tokenResult
              configuration:(__unused MSIDConfiguration *)configuration
                  oidcScope:(__unused NSString *)oidcScope
              correlationID:(NSUUID *)correlationID
                      error:(NSError **)error
{
    if (!tokenResult.account)
    {
        MSID_LOG_ERROR_CORR(correlationID, @"No account returned from server.");
        
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"No account identifier returned from server.", nil, nil, nil, correlationID, nil);
        }
        
        return NO;
    }

    return YES;
}

- (BOOL)validateAccount:(MSIDAccountIdentifier *)accountIdentifier
            tokenResult:(MSIDTokenResult *)tokenResult
          correlationID:(NSUUID *)correlationID
                  error:(NSError **)error
{
    MSID_LOG_NO_PII(MSIDLogLevelVerbose, correlationID, nil, @"Checking returned account");
    MSID_LOG_PII(MSIDLogLevelVerbose, correlationID, nil, @"Checking returned account, Input account id %@, returned account ID %@, local account ID %@", accountIdentifier.displayableId, tokenResult.account.accountIdentifier.displayableId, tokenResult.account.localAccountId);
    
    switch (accountIdentifier.legacyAccountIdentifierType)
    {
        case MSIDLegacyIdentifierTypeRequiredDisplayableId:
        {
            if (!accountIdentifier.displayableId
                || [accountIdentifier.displayableId.lowercaseString isEqualToString:tokenResult.account.accountIdentifier.displayableId.lowercaseString])
            {
                return YES;
            }
            break;
        }
            
        case MSIDLegacyIdentifierTypeUniqueNonDisplayableId:
        {
            if (!accountIdentifier.localAccountId
                || [accountIdentifier.localAccountId.lowercaseString isEqualToString:tokenResult.account.localAccountId.lowercaseString])
            {
                return YES;
            }
            break;
        }
        case MSIDLegacyIdentifierTypeOptionalDisplayableId:
        {
            return YES;
        }
            
        default:
            break;
        
    }
    
    if (error)
    {
        *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorMismatchedAccount, @"Different user was returned by the server then specified in the acquireToken call. If this is a new sign in use and ADUserIdentifier is of OptionalDisplayableId type, pass in the userId returned on the initial authentication flow in all future acquireToken calls.", nil, nil, nil, correlationID, nil);
    }
    
    return NO;
}

@end
