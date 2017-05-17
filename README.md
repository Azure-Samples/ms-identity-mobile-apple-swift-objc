--- 
Services: active-directory
platforms: iOS
author: brandwe
---

Microsoft Authentication Library Graph API Sample for Apple iOS in Swift
=====================================

| [Getting Started](https://apps.dev.microsoft.com/)| [Library](https://github.com/AzureAD/microsoft-authentication-library-for-objc) | [Docs](https://aka.ms/aaddev) | [Support](README.md#community-help-and-support)
| --- | --- | --- | --- |

The MSAL preview library for iOS and macOS gives your app the ability to begin using the [Microsoft Cloud](https://cloud.microsoft.com) by supporting [Microsoft Azure Active Directory](https://azure.microsoft.com/en-us/services/active-directory/) and [Microsoft Accounts](https://account.microsoft.com) in a converged experience using industry standard OAuth2 and OpenID Connect. This sample demonstrates all the normal lifecycles your application should experience, including:

* How to get a token
* How to refresh a token
* How to call the Microsoft Graph API
* How to sign a user out of your application

## Example

```swift
    if let application = try? MSALPublicClientApplication.init(clientId: <your-client-id-here>) {
        application.acquireToken(forScopes: kScopes) { (result, error) in
            if result != nil {
                    // Set up your app for the user
            } else {
                print(error?.localizedDescription)
            }
        }
    }
    else {
            print("Unable to create application.")
        } 
```

## App Registration 

You will need to have a native client application registered with Microsoft using our [App Registration Portal](http://apps.dev.microsoft.com). You must do this even if you have previousdly registered your app with the legact portal. Once done, you will need add the redirect URI of `msal<your-client-id-here>://auth` in the portal.


## Installation

We use [Carthage](https://github.com/Carthage/Carthage) for package management during the preview period of MSAL. This package manager integrates very nicely with XCode while maintaining our ability to make changes to the library. The sample is set up to use Carthage.

##### If you're building for iOS, tvOS, or watchOS

1. Install Carthage on your Mac using a download from their website or if using Homebrew `brew install carthage`.
1. We have already created a `Cartfile` that lists the MSAL library for this project on Github. We use the `/dev` branch.
1. Run `carthage update`. This will fetch dependencies into a `Carthage/Checkouts` folder, then build the MSAL library.
1. On your application targets’ “General” settings tab, in the “Linked Frameworks and Libraries” section, drag and drop the `MSAL.framework` from the `Carthage/Build` folder on disk.
1. On your application targets’ “Build Phases” settings tab, click the “+” icon and choose “New Run Script Phase”. Create a Run Script in which you specify your shell (ex: `/bin/sh`), add the following contents to the script area below the shell:

  ```sh
  /usr/local/bin/carthage copy-frameworks
  ```

  and add the paths to the frameworks you want to use under “Input Files”, e.g.:

  ```
  $(SRCROOT)/Carthage/Build/iOS/MSAL.framework
  ```
  This script works around an [App Store submission bug](http://www.openradar.me/radar?id=6409498411401216) triggered by universal binaries and ensures that necessary bitcode-related files and dSYMs are copied when archiving.

With the debug information copied into the built products directory, Xcode will be able to symbolicate the stack trace whenever you stop at a breakpoint. This will also enable you to step through third-party code in the debugger.

When archiving your application for submission to the App Store or TestFlight, Xcode will also copy these files into the dSYMs subdirectory of your application’s `.xcarchive` bundle.

## Configure your application

1. Add your application's redirect URI scheme to added in the portal to your `info.plist` file. It will be in the format of `msal<client-id>`
```xml
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>CFBundleURLName</key>
            <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>msalyour-client-id-here</string>
            </array>
        </dict>
    </array>
```

2. Configure your application defaults

In the `ViewControler.swift` file, update the `kClientID` variable with your client ID.

```swift
    // Update the below to your client ID you received in the portal. The below is for running the demo only
    
    let kClientID = "<your-client-id-here>"
```

## Community Help and Support

We use [Stack Overflow](http://stackoverflow.com/questions/tagged/msal) with the community to provide support. We highly recommend you ask your questions on Stack Overflow first and browse existing issues to see if someone has asked your question before. 

If you find and bug or have a feature request, please raise the issue on [GitHub Issues](../../issues). 

To provide a recommendation, visit our [User Voice page](https://feedback.azure.com/forums/169401-azure-active-directory).

## Contribute

We enthusiastically welcome contributions and feedback. You can clone the repo and start contributing now. Read our [Contribution Guide](Contributing.md) for more information.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.


Copyright (c) Microsoft Corporation.  All rights reserved. Licensed under the MIT License (the "License");
