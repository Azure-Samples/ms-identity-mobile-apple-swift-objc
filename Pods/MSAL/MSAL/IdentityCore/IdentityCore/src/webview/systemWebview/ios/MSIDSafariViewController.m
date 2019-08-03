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

#if !MSID_EXCLUDE_SYSTEMWV

#import "MSIDSafariViewController.h"
#import "MSIDSystemWebviewController.h"
#import <SafariServices/SafariServices.h>
#import "MSIDWebOAuth2Response.h"
#import "UIApplication+MSIDExtensions.h"
#import "MSIDWebviewAuthorization.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryUIEvent.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDNotifications.h"

@interface MSIDSafariViewController() <SFSafariViewControllerDelegate>

@end

@implementation MSIDSafariViewController
{
    SFSafariViewController *_safariViewController;
    
    NSURL *_startURL;
    
    MSIDWebUICompletionHandler _completionHandler;
    
    id<MSIDRequestContext> _context;
    
    NSString *_telemetryRequestId;
    MSIDTelemetryUIEvent *_telemetryEvent;
}

- (instancetype)initWithURL:(NSURL *)url
           parentController:(UIViewController *)parentController
           presentationType:(UIModalPresentationStyle)presentationType
                    context:(id<MSIDRequestContext>)context
{
    self = [super init];
    if (self)
    {
        _startURL = url;
        _context = context;
        
        _safariViewController = [[SFSafariViewController alloc] initWithURL:url entersReaderIfAvailable:NO];
        _safariViewController.delegate = self;
        _safariViewController.modalPresentationStyle = presentationType;

        _parentController = parentController;
    }
    return self;
}

- (void)cancel
{
    NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorSessionCanceledProgrammatically, @"Authorization session was cancelled programatically", nil, nil, nil, _context.correlationId, nil);
    
    [self completeSessionWithResponse:nil context:_context error:error];
}

- (void)startWithCompletionHandler:(MSIDWebUICompletionHandler)completionHandler
{
    if (!completionHandler)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning,_context, @"CompletionHandler cannot be nil for interactive session.");
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *viewController = _parentController ? _parentController :
        [UIApplication msidCurrentViewController];
        if (!viewController)
        {
            NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorNoMainViewController, @"Failed to start an interactive session - main viewcontroller is nil", nil, nil, nil, _context.correlationId, nil);
            [MSIDNotifications notifyWebAuthDidFailWithError:error];
            completionHandler(nil, error);
            return;
        }
        
        _completionHandler = [completionHandler copy];
        
        _telemetryRequestId = [_context telemetryRequestId];
        
        [[MSIDTelemetry sharedInstance] startEvent:_telemetryRequestId eventName:MSID_TELEMETRY_EVENT_UI_EVENT];
        _telemetryEvent = [[MSIDTelemetryUIEvent alloc] initWithName:MSID_TELEMETRY_EVENT_UI_EVENT
                                                             context:_context];
        
        [MSIDNotifications notifyWebAuthDidStartLoad:_startURL];
        
        [viewController presentViewController:_safariViewController animated:YES completion:nil];
    });
}


- (BOOL)handleURLResponse:(NSURL *)url
{
    if (!url || !_safariViewController)
    {
        return NO;
    }
    
    return [self completeSessionWithResponse:url context:nil error:nil];
}

- (BOOL)completeSessionWithResponse:(NSURL *)url
                            context:(id<MSIDRequestContext>)context
                              error:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [_safariViewController dismissViewControllerAnimated:YES completion:^{
            _safariViewController = nil;
        }];
    });
    
    [[MSIDTelemetry sharedInstance] stopEvent:_telemetryRequestId event:_telemetryEvent];
    
    if (error)
    {
        [MSIDNotifications notifyWebAuthDidFailWithError:error];
        _completionHandler(nil, error);
        return NO;
    }
    
    [MSIDNotifications notifyWebAuthDidCompleteWithURL:url];

    _completionHandler(url, nil);
    return YES;
}


#pragma mark - SFSafariViewControllerDelegate
- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller
{
    // user cancel
    NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorUserCancel, @"User cancelled the authorization session.", nil, nil, nil, _context.correlationId, nil);
    [_telemetryEvent setIsCancelled:YES];
    [self completeSessionWithResponse:nil
                              context:_context error:error];
}

@end
#endif
