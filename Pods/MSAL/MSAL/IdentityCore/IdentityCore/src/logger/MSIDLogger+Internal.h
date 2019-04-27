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

#import "MSIDLogger.h"
#import "MSIDRequestContext.h"

// Convenience macro for obscuring PII in log macros that don't allow PII.
#define _PII_NULLIFY(_OBJ) _OBJ ? @"(not-null)" : @"(null)"

#define MSID_LOG(_LVL, _CORRELATION, _CTX, _PII, _IGNORE_IF_PIIENABLED, _FMT, ...) [[MSIDLogger sharedLogger] logWithLevel:_LVL context:_CTX correlationId:_CORRELATION isPII:_PII ignoreIfPIIEnabled:_IGNORE_IF_PIIENABLED format:_FMT, ##__VA_ARGS__]
#define MSID_LOG_PII(_LVL, _CORRELATION, _CTX, _FMT, ...) MSID_LOG(_LVL, _CORRELATION, _CTX, YES, NO, _FMT, ##__VA_ARGS__)
#define MSID_LOG_NO_PII(_LVL, _CORRELATION, _CTX, _FMT, ...) MSID_LOG(_LVL, _CORRELATION, _CTX, NO, YES, _FMT, ##__VA_ARGS__)

/*
 Macros that take context should be prefered as context provides both log component and correlationId.
 However, ADAL has lots of components that don't know their context and only know their correlationId.
 Also, in some cases correlationId arriving from the broker or in the server response should be used and not the one in context.
 Therefore, _CORR macros are also provided for backward compatibility, but they should be used only when context is not otherwise available.
 */

#define MSID_LOG_ERROR(_ctx, _fmt, ...) \
MSID_LOG(MSIDLogLevelError, nil, _ctx, NO, NO, _fmt, ##__VA_ARGS__)


#define MSID_LOG_ERROR_CORR(_correlationId, _fmt, ...) \
MSID_LOG(MSIDLogLevelError, _correlationId, nil, NO, NO, _fmt, ##__VA_ARGS__)

#define MSID_LOG_ERROR_PII(_ctx, _fmt, ...) \
MSID_LOG(MSIDLogLevelError, nil, _ctx, YES, NO, _fmt, ##__VA_ARGS__)

#define MSID_LOG_WARN(_ctx, _fmt, ...) \
MSID_LOG(MSIDLogLevelWarning, nil, _ctx, NO, NO, _fmt, ##__VA_ARGS__)

#define MSID_LOG_WARN_PII(_ctx, _fmt, ...) \
MSID_LOG(MSIDLogLevelWarning, nil, _ctx, YES, NO, _fmt, ##__VA_ARGS__)

#define MSID_LOG_INFO(_ctx, _fmt, ...) \
MSID_LOG(MSIDLogLevelInfo, nil, _ctx, NO, NO, _fmt, ##__VA_ARGS__)

#define MSID_LOG_INFO_CORR(_correlationId, _fmt, ...) \
MSID_LOG(MSIDLogLevelInfo, _correlationId, nil, NO, NO, _fmt, ##__VA_ARGS__)

#define MSID_LOG_INFO_PII(_ctx, _fmt, ...) \
MSID_LOG(MSIDLogLevelInfo, nil, _ctx, YES, NO, _fmt, ##__VA_ARGS__)

#define MSID_LOG_VERBOSE(_ctx, _fmt, ...) \
MSID_LOG(MSIDLogLevelVerbose, nil, _ctx, NO, NO, _fmt, ##__VA_ARGS__)

#define MSID_LOG_VERBOSE_CORR(_correlationId, _fmt, ...) \
MSID_LOG(MSIDLogLevelVerbose, _correlationId, nil, NO, NO, _fmt, ##__VA_ARGS__)

#define MSID_LOG_VERBOSE_PII(_ctx, _fmt, ...) \
MSID_LOG(MSIDLogLevelVerbose, nil, _ctx, YES, NO, _fmt, ##__VA_ARGS__)

#define MSID_TRACE // Unused

@interface MSIDLogger (Internal)

/*!
 Logs message with the specified level. If correlationId is nil, uses correlationId from the context.
 @param context         Log context, provides correlationId and log component
 @param correlationId   Alternative way to pass correlationId for cases when context is not available
 @param isPii           Specifies if message contains PII
 @param format          Message format

 */

- (void)logWithLevel:(MSIDLogLevel)level
             context:(id<MSIDRequestContext>)context
       correlationId:(NSUUID *)correlationId
               isPII:(BOOL)isPii
  ignoreIfPIIEnabled:(BOOL)ignoreIfPIIEnabled
              format:(NSString *)format, ... NS_FORMAT_FUNCTION(6, 7);

- (void)logToken:(NSString *)token
       tokenType:(NSString *)tokenType
   expiresOnDate:(NSDate *)expiresOn
    additionaLog:(NSString *)additionalLog
         context:(id<MSIDRequestContext>)context;

@end

