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

#import <Foundation/Foundation.h>

@class MSIDCredentialCacheItem;
@class MSIDAccountCacheItem;
@class MSIDCacheKey;
@class MSIDAppMetadataCacheItem;

@protocol MSIDRequestContext;
@protocol MSIDAccountItemSerializer;
@protocol MSIDCredentialItemSerializer;
@protocol MSIDAppMetadataItemSerializer;

@protocol MSIDTokenCacheDataSource <NSObject>

// Tokens
- (BOOL)saveToken:(MSIDCredentialCacheItem *)item
              key:(MSIDCacheKey *)key
       serializer:(id<MSIDCredentialItemSerializer>)serializer
          context:(id<MSIDRequestContext>)context
            error:(NSError **)error;

- (MSIDCredentialCacheItem *)tokenWithKey:(MSIDCacheKey *)key
                          serializer:(id<MSIDCredentialItemSerializer>)serializer
                             context:(id<MSIDRequestContext>)context
                               error:(NSError **)error;

- (NSArray<MSIDCredentialCacheItem *> *)tokensWithKey:(MSIDCacheKey *)key
                                      serializer:(id<MSIDCredentialItemSerializer>)serializer
                                         context:(id<MSIDRequestContext>)context
                                           error:(NSError **)error;

// Wipe info

- (BOOL)saveWipeInfoWithContext:(id<MSIDRequestContext>)context
                          error:(NSError **)error;

- (NSDictionary *)wipeInfo:(id<MSIDRequestContext>)context
                     error:(NSError **)error;

// Removal

- (BOOL)removeItemsWithTokenKey:(MSIDCacheKey *)key
                        context:(id<MSIDRequestContext>)context
                          error:(NSError **)error;

- (BOOL)removeItemsWithAccountKey:(MSIDCacheKey *)key
                          context:(id<MSIDRequestContext>)context
                            error:(NSError **)error;

- (BOOL)removeItemsWithMetadataKey:(MSIDCacheKey *)key
                           context:(id<MSIDRequestContext>)context
                             error:(NSError **)error;

// Accounts

- (BOOL)saveAccount:(MSIDAccountCacheItem *)item
                key:(MSIDCacheKey *)key
         serializer:(id<MSIDAccountItemSerializer>)serializer
            context:(id<MSIDRequestContext>)context
              error:(NSError **)error;

- (MSIDAccountCacheItem *)accountWithKey:(MSIDCacheKey *)key
                              serializer:(id<MSIDAccountItemSerializer>)serializer
                                 context:(id<MSIDRequestContext>)context
                                   error:(NSError **)error;

- (NSArray<MSIDAccountCacheItem *> *)accountsWithKey:(MSIDCacheKey *)key
                                          serializer:(id<MSIDAccountItemSerializer>)serializer
                                             context:(id<MSIDRequestContext>)context
                                               error:(NSError **)error;

- (BOOL)clearWithContext:(id<MSIDRequestContext>)context
                   error:(NSError **)error;

- (BOOL)saveAppMetadata:(MSIDAppMetadataCacheItem *)item
                    key:(MSIDCacheKey *)key
             serializer:(id<MSIDAppMetadataItemSerializer>)serializer
                context:(id<MSIDRequestContext>)context
                  error:(NSError **)error;

- (NSArray<MSIDAppMetadataCacheItem *> *)appMetadataEntriesWithKey:(MSIDCacheKey *)key
                                                        serializer:(id<MSIDAppMetadataItemSerializer>)serializer
                                                           context:(id<MSIDRequestContext>)context
                                                             error:(NSError **)error;

@end
