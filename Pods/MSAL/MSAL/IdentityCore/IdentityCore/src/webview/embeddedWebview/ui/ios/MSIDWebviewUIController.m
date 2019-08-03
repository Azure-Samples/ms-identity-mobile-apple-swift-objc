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

#if !MSID_EXCLUDE_WEBKIT

#import "MSIDWebviewUIController.h"
#import "UIApplication+MSIDExtensions.h"
#import "MSIDAppExtensionUtil.h"

static WKWebViewConfiguration *s_webConfig;

@interface MSIDWebviewUIController ( )
{
    UIActivityIndicatorView *_loadingIndicator;
    
    UIBackgroundTaskIdentifier _bgTask;
    id _bgObserver;
    id _foregroundObserver;
}

@end

@implementation MSIDWebviewUIController

+ (void)initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_webConfig = [WKWebViewConfiguration new];
    });
}

- (id)initWithContext:(id<MSIDRequestContext>)context
{
    self = [super init];
    if (self)
    {
        _context = context;
    }
    
    return self;
}

-(void)dealloc
{
    [self cleanupBackgroundTask];
}

- (BOOL)loadView:(NSError **)error;
{
    /* Start background transition tracking,
     so we can start a background task, when app transitions to background */
    if (![MSIDAppExtensionUtil isExecutingInAppExtension])
    {
        [self startTrackingBackroundAppTransition];
    }
    
    if (_webView)
    {
        return YES;
    }
    
    // Get UI container to hold the webview
    // Need parent controller to proceed
    if (![self obtainParentController])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorNoMainViewController, @"The Application does not have a current ViewController", nil, nil, nil, _context.correlationId, nil);
        }
        return NO;
    }
    UIView *rootView = [self view];
    [rootView setFrame:[[UIScreen mainScreen] bounds]];
    [rootView setAutoresizesSubviews:YES];
    [rootView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    
    // Prepare the WKWebView
    WKWebView *webView = [[WKWebView alloc] initWithFrame:rootView.frame configuration:s_webConfig];
    [webView setAccessibilityIdentifier:@"MSID_SIGN_IN_WEBVIEW"];
    
    // Customize the UI
    [webView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [self setupCancelButton];
    _loadingIndicator = [self prepareLoadingIndicator:rootView];
    self.view = rootView;
    
    // Append webview and loading indicator
    _webView = webView;
    [rootView addSubview:_webView];
    [rootView addSubview:_loadingIndicator];
    
    return YES;
}

- (void)presentView
{
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:self];
    [navController setModalPresentationStyle:_presentationType];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [_parentController presentViewController:navController animated:YES completion:nil];
    });
}

- (void)dismissWebview:(void (^)(void))completion
{
    [self cleanupBackgroundTask];
    
    //if webview is created by us, dismiss and then complete and return;
    //otherwise just complete and return.
    if (_parentController)
    {
        [_parentController dismissViewControllerAnimated:YES completion:completion];
    }
    else
    {
        completion();
    }
    
    _parentController = nil;
}

- (void)showLoadingIndicator
{
    [_loadingIndicator setHidden:NO];
    [_loadingIndicator startAnimating];
}

- (void)dismissLoadingIndicator
{
    [_loadingIndicator setHidden:YES];
    [_loadingIndicator stopAnimating];
}

- (BOOL)obtainParentController
{
    if (_parentController)
    {
        return YES;
    }
    
    _parentController = [UIApplication msidCurrentViewController];
    
    return (_parentController != nil);
}

- (void)setupCancelButton
{
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                  target:self
                                                                                  action:@selector(userCancel)];
    self.navigationItem.leftBarButtonItem = cancelButton;
}

- (UIActivityIndicatorView *)prepareLoadingIndicator:(UIView *)rootView
{
    UIActivityIndicatorView *loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [loadingIndicator setColor:[UIColor blackColor]];
    [loadingIndicator setCenter:rootView.center];
    return loadingIndicator;
}

// This is reserved for subclass to handle programatic cancellation.
- (void)cancel
{
    // Overridden in subclass with cancel logic
}

- (void)userCancel
{
    // Overridden in subclass with userCancel logic
}

#pragma mark - Background task

- (void)startTrackingBackroundAppTransition
{
    if (_bgObserver)
    {
        return;
    }
    
    _bgObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
                                                                    object:nil
                                                                     queue:nil
                                                                usingBlock:^(__unused NSNotification *notification)
                   {
                       MSID_LOG_WITH_CTX(MSIDLogLevelVerbose,_context, @"Application will resign active");
                       [self startTrackingForegroundAppTransition];
                       [self startBackgroundTask];
                   }];
}

- (void)stopTrackingBackgroundAppTransition
{
    if (_bgObserver)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose,_context, @"Stop background application tracking");
        [[NSNotificationCenter defaultCenter] removeObserver:_bgObserver];
        _bgObserver = nil;
    }
}

- (void)startTrackingForegroundAppTransition
{
    if (_foregroundObserver)
    {
        return;
    }
    
    _foregroundObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                                            object:nil
                                                                             queue:nil
                                                                        usingBlock:^(__unused NSNotification * _Nonnull note) {
                                                                            
                                                                            MSID_LOG_WITH_CTX(MSIDLogLevelVerbose,_context, @"Application did become active");
                                                                            [self stopBackgroundTask];
                                                                            [self stopTrackingForegroundAppTransition];
                                                                        }];
}

- (void)stopTrackingForegroundAppTransition
{
    if (_foregroundObserver)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose,_context, @"Stop foreground application tracking");
        
        [[NSNotificationCenter defaultCenter] removeObserver:_foregroundObserver];
        _foregroundObserver = nil;
    }
}

/*
 Background task execution:
 https://forums.developer.apple.com/message/253232#253232
 */

- (void)startBackgroundTask
{
    if (_bgTask != UIBackgroundTaskInvalid)
    {
        // Background task already started
        return;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, _context, @"Start background app task");
    
    _bgTask = [[MSIDAppExtensionUtil sharedApplication] beginBackgroundTaskWithName:@"Interactive login"
                                                                  expirationHandler:^{
                                                                      MSID_LOG_WITH_CTX(MSIDLogLevelInfo, _context, @"Background task expired");
                                                                      [self stopBackgroundTask];
                                                                      [self stopTrackingForegroundAppTransition];
                                                                  }];
}

- (void)stopBackgroundTask
{
    if (_bgTask == UIBackgroundTaskInvalid)
    {
        // Background task already ended or not started
        return;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, _context, @"Stop background task");
    [[MSIDAppExtensionUtil sharedApplication] endBackgroundTask:_bgTask];
    _bgTask = UIBackgroundTaskInvalid;
}

- (void)cleanupBackgroundTask
{
    [self stopTrackingBackgroundAppTransition];
    
    // If authentication is stopped while app is in background
    [self stopTrackingForegroundAppTransition];
    [self stopBackgroundTask];
}

@end

#endif
