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

#import "MSIDKeychainTokenCache+Internal.h"
#import "MSIDCacheKey.h"
#import "MSIDCredentialItemSerializer.h"
#import "MSIDAccountItemSerializer.h"
#import "MSIDKeychainUtil.h"
#import "MSIDError.h"
#import "MSIDRefreshToken.h"
#import "MSIDAppMetadataItemSerializer.h"

NSString *const MSIDAdalKeychainGroup = @"com.microsoft.adalcache";
static NSString *const s_wipeLibraryString = @"Microsoft.ADAL.WipeAll.1";
static MSIDKeychainTokenCache *s_defaultCache = nil;
static NSString *s_defaultKeychainGroup = MSIDAdalKeychainGroup;

@interface MSIDKeychainTokenCache ()

@property (readwrite, nonnull) NSString *keychainGroup;
@property (readwrite, nonnull) NSDictionary *defaultKeychainQuery;
@property (readwrite, nonnull) NSDictionary *defaultWipeQuery;

@end

@implementation MSIDKeychainTokenCache

#pragma mark - Public

+ (NSString *)defaultKeychainGroup
{
    return s_defaultKeychainGroup;
}

+ (void)setDefaultKeychainGroup:(NSString *)defaultKeychainGroup
{
    if (s_defaultCache)
    {
        MSID_LOG_ERROR(nil, @"Failed to set default keychain group, default keychain cache has already been instantiated.");
        
        @throw @"Attempting to change the keychain group once AuthenticationContexts have been created or the default keychain cache has been retrieved is invalid. The default keychain group should only be set once for the lifetime of an application.";
    }
    
    MSID_LOG_NO_PII(MSIDLogLevelInfo, nil, nil, @"Setting default keychain group.");
    MSID_LOG_PII(MSIDLogLevelInfo, nil, nil, @"Setting default keychain group to %@", defaultKeychainGroup);
    
    if ([defaultKeychainGroup isEqualToString:s_defaultKeychainGroup])
    {
        return;
    }
    
    if (!defaultKeychainGroup)
    {
        defaultKeychainGroup = [[NSBundle mainBundle] bundleIdentifier];
    }
    
    s_defaultKeychainGroup = [defaultKeychainGroup copy];
}

+ (MSIDKeychainTokenCache *)defaultKeychainCache
{
    static dispatch_once_t s_once;
    
    dispatch_once(&s_once, ^{
        s_defaultCache = [[MSIDKeychainTokenCache alloc] init];
    });
    
    return s_defaultCache;
}

- (nonnull instancetype)init
{
    return [self initWithGroup:s_defaultKeychainGroup];
}

- (nullable instancetype)initWithGroup:(nullable NSString *)keychainGroup
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    if (!keychainGroup)
    {
        keychainGroup = [[NSBundle mainBundle] bundleIdentifier];
    }
    
    if (!MSIDKeychainUtil.teamId) return nil;
    
    // Add team prefix to keychain group if it is missed.
    if (![keychainGroup hasPrefix:MSIDKeychainUtil.teamId])
    {
        keychainGroup = [MSIDKeychainUtil accessGroup:keychainGroup];
    }
    
    _keychainGroup = keychainGroup;
    
    if (!_keychainGroup)
    {
        return nil;
    }
    
    self.defaultKeychainQuery = [@{(id)kSecClass : (id)kSecClassGenericPassword,
                                   (id)kSecAttrAccessGroup : self.keychainGroup} mutableCopy];
    
    self.defaultWipeQuery = @{(id)kSecClass : (id)kSecClassGenericPassword,
                              (id)kSecAttrGeneric : [s_wipeLibraryString dataUsingEncoding:NSUTF8StringEncoding],
                              (id)kSecAttrAccessGroup : self.keychainGroup,
                              (id)kSecAttrAccount : @"TokenWipe"};
    
    MSID_LOG_NO_PII(MSIDLogLevelInfo, nil, nil, @"Init MSIDKeychainTokenCache with keychainGroup: %@", [self keychainGroupLoggingName]);
    MSID_LOG_PII(MSIDLogLevelInfo, nil, nil, @"Init MSIDKeychainTokenCache with keychainGroup: %@", _keychainGroup);
    
    return self;
}

#pragma mark - Tokens

- (BOOL)saveToken:(MSIDCredentialCacheItem *)item
              key:(MSIDCacheKey *)key
       serializer:(id<MSIDCredentialItemSerializer>)serializer
          context:(id<MSIDRequestContext>)context
            error:(NSError **)error
{
    assert(item);
    assert(serializer);

    if (!key.generic)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Key is not valid. Make sure generic field is not nil.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Set keychain item with invalid key.");
        return NO;
    }
    
    MSIDCacheKey *tokenCacheKey = [self overrideTokenKey:key];
    
    NSData *itemData = [serializer serializeCredentialCacheItem:item];
    
    if (!itemData)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to serialize token item.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Failed to serialize token item.");
        return NO;
    }
    
    MSID_LOG_INFO_PII(context, @"Saving keychain item, item info %@", item);
    
    return [self saveData:itemData
                      key:tokenCacheKey
                  context:context
                    error:error];
}

- (MSIDCredentialCacheItem *)tokenWithKey:(MSIDCacheKey *)key
                               serializer:(id<MSIDCredentialItemSerializer>)serializer
                                  context:(id<MSIDRequestContext>)context
                                    error:(NSError **)error
{
    MSID_LOG_VERBOSE(context, @"itemWithKey:serializer:context:error:");
    NSArray<MSIDCredentialCacheItem *> *items = [self tokensWithKey:key serializer:serializer context:context error:error];
    
    if (items.count > 1)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorCacheMultipleUsers, @"The token cache store for this resource contains more than one user.", nil, nil, nil, context.correlationId, nil);
        }
        
        return nil;
    }
    
    return items.firstObject;
}

- (NSArray<MSIDCredentialCacheItem *> *)tokensWithKey:(MSIDCacheKey *)key
                                           serializer:(id<MSIDCredentialItemSerializer>)serializer
                                              context:(id<MSIDRequestContext>)context
                                                error:(NSError **)error
{
    MSIDCacheKey *tokenCacheKey = [self overrideTokenKey:key];
    
    NSArray *items = [self itemsWithKey:tokenCacheKey context:context error:error];
    
    if (!items)
    {
        return nil;
    }
    
    NSMutableArray *tokenItems = [self filterTokenItemsFromKeychainItems:items
                                                              serializer:serializer
                                                                 context:context];
    
    MSID_LOG_VERBOSE(context, @"Found %lu items.", (unsigned long)tokenItems.count);

    
    return tokenItems;
}

#pragma mark - Accounts

- (BOOL)saveAccount:(MSIDAccountCacheItem *)item
                key:(MSIDCacheKey *)key
         serializer:(id<MSIDAccountItemSerializer>)serializer
            context:(id<MSIDRequestContext>)context
              error:(NSError **)error
{
    assert(item);
    assert(serializer);
    
    NSData *itemData = [serializer serializeAccountCacheItem:item];
    
    if (!itemData)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to serialize account item.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Failed to serialize token item.");
        return NO;
    }
    
    MSID_LOG_INFO_PII(context, @"Saving keychain item, item info %@", item);
    
    return [self saveData:itemData
                      key:key
                  context:context
                    error:error];
}

- (MSIDAccountCacheItem *)accountWithKey:(MSIDCacheKey *)key
                              serializer:(id<MSIDAccountItemSerializer>)serializer
                                 context:(id<MSIDRequestContext>)context
                                   error:(NSError **)error
{
    NSArray<MSIDAccountCacheItem *> *items = [self accountsWithKey:key serializer:serializer context:context error:error];
    
    if (items.count > 1)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorCacheMultipleUsers, @"The token cache store for this resource contains more than one user.", nil, nil, nil, context.correlationId, nil);
        }
        
        return nil;
    }
    
    return items.firstObject;
}

- (NSArray<MSIDAccountCacheItem *> *)accountsWithKey:(MSIDCacheKey *)key
                                          serializer:(id<MSIDAccountItemSerializer>)serializer
                                             context:(id<MSIDRequestContext>)context
                                               error:(NSError **)error
{
    NSArray *items = [self itemsWithKey:key context:context error:error];
    
    if (!items)
    {
        return nil;
    }
    
    NSMutableArray *accountItems = [[NSMutableArray<MSIDAccountCacheItem *> alloc] initWithCapacity:items.count];
    
    for (NSDictionary *attrs in items)
    {
        NSData *itemData = [attrs objectForKey:(id)kSecValueData];
        MSIDAccountCacheItem *accountItem = [serializer deserializeAccountCacheItem:itemData];
        
        if (accountItem)
        {
            [accountItems addObject:accountItem];
        }
        else
        {
            MSID_LOG_INFO(context, @"Failed to deserialize account item.");
        }
    }
    
    MSID_LOG_VERBOSE(context, @"Found %lu items.", (unsigned long)accountItems.count);
    
    return accountItems;
}

#pragma mark - Metadata

- (BOOL)saveAppMetadata:(MSIDAppMetadataCacheItem *)item
                    key:(MSIDCacheKey *)key
             serializer:(id<MSIDAppMetadataItemSerializer>)serializer
                context:(id<MSIDRequestContext>)context
                  error:(NSError **)error
{
    if (!item || !serializer)
    {
        if (error)
        {
            NSString *errorMessage = @"Item or serializer is nil while saving app metadata!";
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, errorMessage, nil, nil, nil, context.correlationId, nil);
        }
        return NO;
    }
    
    NSData *itemData = [serializer serializeAppMetadataCacheItem:item];
    
    if (!itemData)
    {
        if (error)
        {
            NSString *errorMessage = @"Failed to serialize app metadata item.";
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, errorMessage, nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Failed to serialize app metadata item.");
        return NO;
    }
    
    MSID_LOG_VERBOSE(context, @"Saving keychain item, item info %@", item);
    
    return [self saveData:itemData
                      key:key
                  context:context
                    error:error];
}

- (NSArray<MSIDAppMetadataCacheItem *> *)appMetadataEntriesWithKey:(MSIDCacheKey *)key
                                                        serializer:(id<MSIDAppMetadataItemSerializer>)serializer
                                                           context:(id<MSIDRequestContext>)context
                                                             error:(NSError **)error
{
    
    NSArray *items = [self itemsWithKey:key context:context error:error];
    
    if (!items)
    {
        return nil;
    }
    
    NSMutableArray *appMetadataitems = [[NSMutableArray<MSIDAppMetadataCacheItem *> alloc] initWithCapacity:items.count];
    
    for (NSDictionary *attrs in items)
    {
        NSData *itemData = [attrs objectForKey:(id)kSecValueData];
        MSIDAppMetadataCacheItem *appMetadata = [serializer deserializeAppMetadataCacheItem:itemData];
        
        if (appMetadata)
        {
            [appMetadataitems addObject:appMetadata];
        }
        else
        {
            MSID_LOG_INFO(context, @"Failed to deserialize app metadata item.");
        }
    }
    
    MSID_LOG_VERBOSE(context, @"Found %lu items.", (unsigned long)appMetadataitems.count);
    
    return appMetadataitems;
}

#pragma mark - Removal

- (BOOL)removeItemsWithTokenKey:(MSIDCacheKey *)key
                        context:(id<MSIDRequestContext>)context
                          error:(NSError **)error
{
    MSIDCacheKey *tokenCacheKey = [self overrideTokenKey:key];
    
    return [self removeItemsWithKey:tokenCacheKey context:context error:error];
}

- (BOOL)removeItemsWithAccountKey:(MSIDCacheKey *)key
                          context:(id<MSIDRequestContext>)context
                            error:(NSError **)error
{
    return [self removeItemsWithKey:key context:context error:error];
}

- (BOOL)removeItemsWithMetadataKey:(MSIDCacheKey *)key
                           context:(id<MSIDRequestContext>)context
                             error:(NSError **)error
{
    return [self removeItemsWithKey:key context:context error:error];
}

- (BOOL)removeItemsWithKey:(MSIDCacheKey *)key
                   context:(id<MSIDRequestContext>)context
                     error:(NSError **)error
{
    NSString *account = key.account;
    NSString *service = key.service;
    NSData *generic = key.generic;
    NSNumber *type = key.type;
    
    MSID_LOG_NO_PII(MSIDLogLevelVerbose, nil, context, @"Remove keychain items, key info (account: %@ service: %@, keychainGroup: %@)", _PII_NULLIFY(account), _PII_NULLIFY(service), [self keychainGroupLoggingName]);
    MSID_LOG_PII(MSIDLogLevelVerbose, nil, context, @"Remove keychain items, key info (account: %@ service: %@, keychainGroup: %@)", account, service, self.keychainGroup);
    
    if (!key)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter, @"Key is nil.", nil, nil, nil, context.correlationId, nil);
        }
        
        return NO;
    }
    
    NSMutableDictionary *query = [self.defaultKeychainQuery mutableCopy];
    if (service)
    {
        [query setObject:service forKey:(id)kSecAttrService];
    }
    if (account)
    {
        [query setObject:account forKey:(id)kSecAttrAccount];
    }
    if (generic)
    {
        [query setObject:generic forKey:(id)kSecAttrGeneric];
    }
    if (type != nil)
    {
        [query setObject:type forKey:(id)kSecAttrType];
    }
    
    if (key.appKeyHash != nil)
    {
        [query setObject:key.appKeyHash forKey:(id)kSecAttrCreator];
    }
    
    MSID_LOG_VERBOSE(context, @"Trying to delete keychain items...");
    OSStatus status = SecItemDelete((CFDictionaryRef)query);
    MSID_LOG_INFO(context, @"Keychain delete status: %d", (int)status);
    
    if (status != errSecSuccess && status != errSecItemNotFound)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDKeychainErrorDomain, status, @"Failed to remove items from keychain.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Failed to delete keychain items (status: %d)", (int)status);
        
        return NO;
    }
        
    return YES;
}

#pragma mark - Wipe

- (BOOL)saveWipeInfoWithContext:(id<MSIDRequestContext>)context
                          error:(NSError **)error
{
    NSDictionary *wipeInfo = @{ @"bundleId" : [[NSBundle mainBundle] bundleIdentifier],
                                @"wipeTime" : [NSDate date]
                                };

    MSID_LOG_INFO_PII(context, @"Full wipe info: %@", wipeInfo);
    
    NSData *wipeData = [NSKeyedArchiver archivedDataWithRootObject:wipeInfo];
    
    MSID_LOG_NO_PII(MSIDLogLevelVerbose, nil, context, @"Trying to update wipe info...");
    MSID_LOG_PII(MSIDLogLevelVerbose, nil, context,@"Wipe query: %@", self.defaultWipeQuery);
    
    OSStatus status = SecItemUpdate((CFDictionaryRef)self.defaultWipeQuery, (CFDictionaryRef)@{ (id)kSecValueData:wipeData});
    MSID_LOG_VERBOSE(context, @"Update wipe info status: %d", (int)status);
    if (status == errSecItemNotFound)
    {
        NSMutableDictionary *mutableQuery = [self.defaultWipeQuery mutableCopy];
        [mutableQuery addEntriesFromDictionary: @{(id)kSecAttrAccessible : (id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                                                  (id)kSecValueData : wipeData}];
        MSID_LOG_VERBOSE(context, @"Trying to add wipe info...");
        status = SecItemAdd((CFDictionaryRef)mutableQuery, NULL);
        MSID_LOG_VERBOSE(context, @"Add wipe info status: %d", (int)status);
    }
    
    if (status != errSecSuccess)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDKeychainErrorDomain, status, @"Failed to save wipe token data into keychain.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Failed to save wipe token data into keychain (status: %d)", (int)status);
        return NO;
    }
    
    return YES;
}

- (NSDictionary *)wipeInfo:(id<MSIDRequestContext>)context
                     error:(NSError **)error;
{
    NSMutableDictionary *query = [self.defaultWipeQuery mutableCopy];
    [query setObject:@YES forKey:(id)kSecReturnData];
    //For compatibility, remove kSecAttrService to be able to read wipeInfo written by old ADAL
    [query removeObjectForKey:(id)kSecAttrService];
    
    CFTypeRef data = nil;
    MSID_LOG_NO_PII(MSIDLogLevelVerbose, nil, context, @"Trying to get wipe info...");
    MSID_LOG_PII(MSIDLogLevelVerbose, nil, context, @"Wipe query: %@", self.defaultWipeQuery);
    
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, &data);
    MSID_LOG_VERBOSE(context, @"Get wipe info status: %d", (int)status);
    
    if (status != errSecSuccess)
    {
        if (error && status != errSecItemNotFound)
        {
            *error = MSIDCreateError(MSIDKeychainErrorDomain, status, @"Failed to get a wipe data from keychain.", nil, nil, nil, context.correlationId, nil);
            MSID_LOG_ERROR(context, @"Failed to get a wipe data from keychain (status: %d)", (int)status);
        }
        
        return nil;
    }
    
    NSDictionary *wipeData = [NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData *)(data)];
    CFRelease(data);
    
    return wipeData;
}

#pragma mark - Protected

- (NSString *)keychainGroupLoggingName
{
    if ([self.keychainGroup containsString:MSIDAdalKeychainGroup])
    {
        return @"adal keychain group";
    }
    
    return _PII_NULLIFY(_keychainGroup);
}

- (NSMutableArray<MSIDCredentialCacheItem *> *)filterTokenItemsFromKeychainItems:(NSArray *)items
                                                                      serializer:(id<MSIDCredentialItemSerializer>)serializer
                                                                         context:(id<MSIDRequestContext>)context
{
    NSMutableArray *tokenItems = [[NSMutableArray<MSIDCredentialCacheItem *> alloc] initWithCapacity:items.count];
    
    for (NSDictionary *attrs in items)
    {
        NSData *itemData = [attrs objectForKey:(id)kSecValueData];
        MSIDCredentialCacheItem *tokenItem = [serializer deserializeCredentialCacheItem:itemData];
        tokenItem.appKey = [self extractAppKey:attrs[(id)kSecAttrService]];
        
        if (tokenItem)
        {
            // Delete tombstones generated from previous versions of ADAL.
            if ([tokenItem isTombstone])
            {
                [self deleteTombstoneWithService:attrs[(id)kSecAttrService]
                                         account:attrs[(id)kSecAttrAccount]
                                         context:context];
            }
            else
            {
                [tokenItems addObject:tokenItem];
            }
        }
        else
        {
            MSID_LOG_INFO(context, @"Failed to deserialize token item.");
        }
    }
    
    return tokenItems;
}

// Override the following function in subclasses if special key handling is needed
- (MSIDCacheKey *)overrideTokenKey:(MSIDCacheKey *)key
{
    return key;
}

- (NSString *)extractAppKey:(NSString *)cacheKeyString
{
    // no app key needs to be set here
    return nil;
}

#pragma mark - Private

- (void)deleteTombstoneWithService:(NSString *)service account:(NSString *)account context:(id<MSIDRequestContext>)context
{
    if (!service || !account)
    {
        return;
    }
    
    NSMutableDictionary *deleteQuery = [self.defaultKeychainQuery mutableCopy];
    [deleteQuery setObject:service forKey:(id)kSecAttrService];
    [deleteQuery setObject:account forKey:(id)kSecAttrAccount];
    
    MSID_LOG_VERBOSE(context, @"Trying to delete tombstone item...");
    OSStatus status = SecItemDelete((CFDictionaryRef)deleteQuery);
    MSID_LOG_VERBOSE(context, @"Keychain delete status: %d", (int)status);
}

#pragma mark - Helpers

- (NSArray *)itemsWithKey:(MSIDCacheKey *)key
                  context:(id<MSIDRequestContext>)context
                    error:(NSError **)error
{
    NSString *account = key.account;
    NSString *service = key.service;
    NSData *generic = key.generic;
    NSNumber *type = key.type;
    
    MSID_LOG_NO_PII(MSIDLogLevelVerbose, nil, context, @"Get keychain items, key info (account: %@ service: %@ generic: %@ type: %@, keychainGroup: %@)", _PII_NULLIFY(account), service, _PII_NULLIFY(generic), type, [self keychainGroupLoggingName]);
    MSID_LOG_PII(MSIDLogLevelVerbose, nil, context, @"Get keychain items, key info (account: %@ service: %@ generic: %@ type: %@, keychainGroup: %@)", account, service, generic, type, self.keychainGroup);
    
    NSMutableDictionary *query = [self.defaultKeychainQuery mutableCopy];
    if (service)
    {
        [query setObject:service forKey:(id)kSecAttrService];
    }
    if (account)
    {
        [query setObject:account forKey:(id)kSecAttrAccount];
    }
    if (generic)
    {
        [query setObject:generic forKey:(id)kSecAttrGeneric];
    }
    if (type != nil)
    {
        [query setObject:type forKey:(id)kSecAttrType];
    }
    if (key.appKeyHash != nil)
    {
        [query setObject:key.appKeyHash forKey:(id)kSecAttrCreator];
    }
    
    [query setObject:@YES forKey:(id)kSecReturnData];
    [query setObject:@YES forKey:(id)kSecReturnAttributes];
    [query setObject:(id)kSecMatchLimitAll forKey:(id)kSecMatchLimit];
    
    CFTypeRef cfItems = nil;
    MSID_LOG_VERBOSE(context, @"Trying to find keychain items...");
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, &cfItems);
    MSID_LOG_INFO(context, @"Keychain find status: %d", (int)status);
    
    if (status == errSecItemNotFound)
    {
        return @[];
    }
    else if (status != errSecSuccess)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDKeychainErrorDomain, status, @"Failed to get items from keychain.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Failed to find keychain item (status: %d)", (int)status);
        return nil;
    }
    
    NSArray *items = CFBridgingRelease(cfItems);
    return items;
}

- (BOOL)saveData:(NSData *)itemData
             key:(MSIDCacheKey *)key
         context:(id<MSIDRequestContext>)context
           error:(NSError **)error
{
    assert(key);
    
    NSString *account = key.account;
    NSString *service = key.service;
    NSData *generic = key.generic;
    NSNumber *type = key.type;
    
    MSID_LOG_NO_PII(MSIDLogLevelVerbose, nil, context, @"Set keychain item, key info (account: %@ service: %@, keychainGroup: %@)", _PII_NULLIFY(account), _PII_NULLIFY(service), [self keychainGroupLoggingName]);
    MSID_LOG_PII(MSIDLogLevelVerbose, nil, context, @"Set keychain item, key info (account: %@ service: %@, keychainGroup: %@)", account, service, self.keychainGroup);
    
    if (!service)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Key is not valid. Make sure service field is not nil.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Set keychain item with invalid key.");
        return NO;
    }
    
    if (!itemData)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Failed to serialize token item.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Failed to serialize token item.");
        return NO;
    }
    
    NSMutableDictionary *query = [self.defaultKeychainQuery mutableCopy];
    [query setObject:service forKey:(id)kSecAttrService];
    [query setObject:(account ? account : @"") forKey:(id)kSecAttrAccount];
    
    if (type != nil)
    {
        [query setObject:type forKey:(id)kSecAttrType];
    }
    
    MSID_LOG_VERBOSE(context, @"Trying to update keychain item...");

    NSMutableDictionary *updateDictionary = [@{(id)kSecValueData : itemData} mutableCopy];

    if (generic)
    {
        updateDictionary[(id)kSecAttrGeneric] = generic;
    }

    OSStatus status = SecItemUpdate((CFDictionaryRef)query, (CFDictionaryRef)updateDictionary);
    MSID_LOG_VERBOSE(context, @"Keychain update status: %d", (int)status);
    if (status == errSecItemNotFound)
    {
        [query setObject:itemData forKey:(id)kSecValueData];

        if (generic)
        {
            [query setObject:generic forKey:(id)kSecAttrGeneric];
        }
        
        if (key.appKeyHash != nil)
        {
            [query setObject:key.appKeyHash forKey:(id)kSecAttrCreator];
        }

        [query setObject:(id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly forKey:(id)kSecAttrAccessible];
        
        MSID_LOG_VERBOSE(context, @"Trying to add keychain item...");
        status = SecItemAdd((CFDictionaryRef)query, NULL);
        MSID_LOG_VERBOSE(context, @"Keychain add status: %d", (int)status);
    }
    
    if (status != errSecSuccess)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDKeychainErrorDomain, status, @"Failed to set item into keychain.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Failed to set item into keychain (status: %d)", (int)status);
    }
    
    return status == errSecSuccess;
}

- (BOOL)clearWithContext:(id<MSIDRequestContext>)context
                   error:(NSError **)error
{
    MSID_LOG_WARN(context, @"Clearing the whole context. This should only be executed in tests");

    NSMutableDictionary *query = [self.defaultKeychainQuery mutableCopy];
    MSID_LOG_VERBOSE(context, @"Trying to delete keychain items...");
    OSStatus status = SecItemDelete((CFDictionaryRef)query);
    MSID_LOG_VERBOSE(context, @"Keychain delete status: %d", (int)status);

    if (status != errSecSuccess && status != errSecItemNotFound)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDKeychainErrorDomain, status, @"Failed to remove items from keychain.", nil, nil, nil, context.correlationId, nil);
        }
        MSID_LOG_ERROR(context, @"Failed to delete keychain items (status: %d)", (int)status);

        return NO;
    }

    return YES;
}

@end

