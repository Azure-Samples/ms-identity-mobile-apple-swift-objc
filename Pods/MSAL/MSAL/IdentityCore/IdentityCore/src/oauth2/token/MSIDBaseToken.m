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

#import "MSIDBaseToken.h"
#import "MSIDUserInformation.h"
#import "MSIDAADTokenResponse.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDClientInfo.h"
#import "MSIDAuthority.h"
#import "MSIDAuthorityFactory.h"
#import "MSIDAccountIdentifier.h"

@implementation MSIDBaseToken

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSIDBaseToken *item = [[self.class allocWithZone:zone] init];
    item->_authority = [_authority copyWithZone:zone];
    item->_storageAuthority = [_storageAuthority copyWithZone:zone];
    item->_clientId = [_clientId copyWithZone:zone];
    item->_accountIdentifier = [_accountIdentifier copyWithZone:zone];
    item->_additionalServerInfo = [_additionalServerInfo copyWithZone:zone];
    return item;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }
    
    if (![object isKindOfClass:self.class])
    {
        return NO;
    }
    
    return [self isEqualToItem:(MSIDBaseToken *)object];
}

- (NSUInteger)hash
{
    NSUInteger hash = 0;
    hash = hash * 31 + self.authority.hash;
    hash = hash * 31 + self.storageAuthority.hash;
    hash = hash * 31 + self.clientId.hash;
    hash = hash * 31 + self.accountIdentifier.hash;
    hash = hash * 31 + self.additionalServerInfo.hash;
    hash = hash * 31 + self.credentialType;
    return hash;
}

- (BOOL)isEqualToItem:(MSIDBaseToken *)item
{
    if (!item)
    {
        return NO;
    }
    
    BOOL result = YES;
    result &= (!self.authority && !item.authority) || [self.authority isEqual:item.authority];
    result &= (!self.storageAuthority && !item.storageAuthority) || [self.storageAuthority isEqual:item.storageAuthority];
    result &= (!self.clientId && !item.clientId) || [self.clientId isEqualToString:item.clientId];
    result &= (!self.accountIdentifier && !item.accountIdentifier) || [self.accountIdentifier isEqual:item.accountIdentifier];
    result &= (!self.additionalServerInfo && !item.additionalServerInfo) || [self.additionalServerInfo isEqualToDictionary:item.additionalServerInfo];
    result &= (self.credentialType == item.credentialType);
    
    return result;
}

#pragma mark - Token type

- (MSIDCredentialType)credentialType
{
    return MSIDCredentialTypeOther;
}

- (BOOL)supportsCredentialType:(MSIDCredentialType)credentialType
{
    return credentialType == self.credentialType;
}

#pragma mark - Cache

- (instancetype)initWithTokenCacheItem:(MSIDCredentialCacheItem *)tokenCacheItem
{
    self = [super init];
    
    if (self)
    {
        if (!tokenCacheItem)
        {
            return nil;
        }
        
        if (![self supportsCredentialType:tokenCacheItem.credentialType])
        {
            MSID_LOG_ERROR(nil, @"Trying to initialize with a wrong token type");
            return nil;
        }

        NSString *environment = tokenCacheItem.environment;
        NSString *tenant = tokenCacheItem.realm;

        __auto_type authorityUrl = [NSURL msidURLWithEnvironment:environment tenant:tenant];
        _authority = [MSIDAuthorityFactory authorityFromUrl:authorityUrl rawTenant:tenant context:nil error:nil];
        
        if (!_authority)
        {
            MSID_LOG_ERROR(nil, @"Trying to initialize token when missing authority field");
            return nil;
        }
        
        _clientId = tokenCacheItem.clientId;
        
        if (!_clientId)
        {
            MSID_LOG_ERROR(nil, @"Trying to initialize token when missing clientId field");
            return nil;
        }
        
        _additionalServerInfo = tokenCacheItem.additionalInfo;

        if (tokenCacheItem.homeAccountId)
        {
            _accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil homeAccountId:tokenCacheItem.homeAccountId];
        }
    }
    
    return self;
}

- (MSIDCredentialCacheItem *)tokenCacheItem
{
    MSIDCredentialCacheItem *cacheItem = [[MSIDCredentialCacheItem alloc] init];
    cacheItem.credentialType = self.credentialType;

    if (self.storageAuthority)
    {
        cacheItem.environment = self.storageAuthority.url.msidHostWithPortIfNecessary;
    }
    else
    {
        cacheItem.environment = self.authority.environment;
    }

    cacheItem.realm = self.authority.url.msidTenant;
    cacheItem.clientId = self.clientId;
    cacheItem.additionalInfo = self.additionalServerInfo;
    cacheItem.homeAccountId = self.accountIdentifier.homeAccountId;
    return cacheItem;
}

#pragma mark - Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"(authority=%@ clientId=%@ credentialType=%@ homeAccountId=%@)",
            _authority, _clientId, [MSIDCredentialTypeHelpers credentialTypeAsString:self.credentialType], _accountIdentifier.homeAccountId];
}

@end
