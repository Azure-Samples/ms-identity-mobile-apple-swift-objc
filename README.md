---
page_type: sample
languages:
- swift
description: "The MSAL preview library for iOS and macOS gives your app the ability to begin using the Microsoft Cloud by supporting Microsoft Entra ID and Microsoft Accounts in a converged experience using industry standard OAuth2 and OpenID Connect."
urlFragment: ios-ms-graph-api
---

# MSAL iOS Swift Microsoft Graph API Sample

![Build Badge](https://identitydivision.visualstudio.com/_apis/public/build/definitions/a7934fdd-dcde-4492-a406-7fad6ac00e17/523/badge)

| [Getting Started](https://docs.microsoft.com/azure/active-directory/develop/guidedsetups/active-directory-ios)| [Library](https://github.com/AzureAD/microsoft-authentication-library-for-objc) | [API Reference](https://azuread.github.io/docs/objc/) | [Support](README.md#feedback,community-help,-and-support)
| --- | --- | --- | --- |

The MSAL library for iOS gives your app the ability to begin using the [Microsoft identity platform](https://aka.ms/aaddev) by supporting [Microsoft Entra ID](https://azure.microsoft.com/en-us/services/active-directory/) and [Microsoft Accounts](https://account.microsoft.com) in a converged experience using industry standard OAuth2 and OpenID Connect. This sample demonstrates all the normal lifecycle your application should experience, including:

- How to get a token
- How to refresh a token
- How to call the Microsoft Graph API
- How to sign a user out of your application

## Scenario

This app is a multi-tenant app meaning it can be used within any Microsoft Entra tenant and also supports signing in with Microsoft Account.  It demonstrates how a developer can build apps to connect with enterprise users and access their Azure + O365 data via the Microsoft Graph.  During the auth flow, end users will be required to sign in and consent to the permissions of the application, and in some cases may require an admin to consent to the app.  The majority of the logic in this sample shows how to auth an end user and make a basic call to the Microsoft Graph.

![Topology](./images/iosintro.png)

## How to run this sample

To run this sample, you'll need:

* Xcode
* An internet connection

## Step 1:

## 1A: Clone or download this repository

From Terminal:

```terminal
git clone https://github.com/Azure-Samples/ms-identity-mobile-apple-swift-objc.git
```
or download and extract the repository.zip file, and navigate to 'MSALiOS.xcworkspace' from the active-directory-ios-swift-native-v2 folder

## 1B: Installation

Load the podfile using cocoapods. This will create a new XCode Workspace you will load.

From terminal navigate to the directory where the podfile is located

```
$ pod install
...
$ open MSALiOS.xcworkspace
```

## Step 2: Register your App (Optional)

This app comes pre-configured for testing. If you would like to register your own app, please follow the steps below.

1. Sign in to the [Microsoft Entra Admin Center](https://entra.microsoft.com) using either a work or school account.
2. In the left-hand navigation pane, select the **Microsoft Entra ID** blade, and then select **App registrations**.
3. Click on the **New registration** button at the top left of the page.
4. On the app registration page,
   - Name your app
   - Under **Supported account types**, select **Accounts in any organizational directory (Any Microsoft Entra ID tenant - Multitenant) and personal Microsoft accounts (e.g. Skype, Xbox)**
   - Click **Register** to finish.
5. After the app is created, you'll land on your app management page. Take note of the **Application (client) ID** as this would be needed for the step 2B below.
6. Click **Authentication**, and add new Redirect URI with type **Public client (mobile & desktop)**. Enter redirect URI in format: `msauth.<app_bundle_id>://auth`. Replace <app_bundle_id> with the **Bundle Identifier** for your application. 
7. Hit the **Save** button in the top left, to save these updates.
8. Click **Make this change for me** and then download the code sample for iOS

## Step 3: Run the sample

1. Click the Run Button in the top menu or go to Product from the menu tab and click Run.
2. Once the sample app launches, click on the 'Call Microsoft Graph API' button to go through the sign in flow and see the results from Microsoft Graph.

## How to add MSAL library into your existing Xcode project

## Step 1: Configure your application Info.plist

Add URI scheme in the  `Info.plist`. Redirect URI scheme follows the format `msauth.[app_bundle_id]`. Make sure to substitute [app_bundle_id] with the **Bundle Identifier** for your application.

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>msauth.[app_bundle_id]</string>
    </array>
  </dict>
</array>
```

## Step 2: Configure your application defaults

In your app, add the `kClientID` variable with your Application (client) ID.

```swift
// For example, you can declare a client id in this way. Below ID is just a sample.
    	
let kClientID = "66855f8a-60cd-445e-a9bb-8cd8eadbd3fa"
```

Add variables with your Microsoft Entra authority and Microsoft Graph endpoint for your national cloud.

```swift
let kGraphEndpoint = "https://graph.microsoft.com/"
let kAuthority = "https://login.microsoftonline.com/common"
```

Other endpoints are documented [here](https://docs.microsoft.com/en-us/graph/deployments#app-registration-and-token-service-root-endpoints). For example, to run the sample with Azure Germany, use following:

```swift
let kGraphEndpoint = "https://graph.microsoft.de/"
let kAuthority = "https://login.microsoftonline.de/common"
```

## Step 3: Configure Xcode project settings

Add a new keychain group to your project **Signing & Capabilities**. The keychain group should be `com.microsoft.adalcache` on iOS.

![Xcode UI displaying how the the keychain group should be set up](./images/iosintro-keychainShare.png)

## Feedback, Community Help, and Support

We use [Stack Overflow](http://stackoverflow.com/questions/tagged/msal) with the community to provide support. We highly recommend you ask your questions on Stack Overflow first and browse existing issues to see if someone has asked your question before.

If you find a bug or have a feature request, please raise the issue on [GitHub Issues](../../issues).

To provide a recommendation, visit our [User Voice page](https://feedback.azure.com/forums/169401-azure-active-directory).

## Contribute

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).

For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Security Library

This library controls how users sign-in and access services. We recommend you always take the latest version of our library in your app when possible. We use [semantic versioning](http://semver.org) so you can control the risk associated with updating your app. As an example, always downloading the latest minor version number (e.g. x.*y*.x) ensures you get the latest security and feature enhancements but our API surface remains the same. You can always see the latest version and release notes under the Releases tab of GitHub.

## Security Reporting

If you find a security issue with our libraries or services please report it to [secure@microsoft.com](mailto:secure@microsoft.com) with as much detail as possible. Your submission may be eligible for a bounty through the [Microsoft Bounty](http://aka.ms/bugbounty) 
program. Please do not post security issues to GitHub Issues or any other public site. We will contact you shortly upon receiving the information. We encourage you to get notifications of when security incidents occur by visiting [this page](https://technet.microsoft.com/en-us/security/dd252948) and subscribing to Security Advisory Alerts.

Copyright (c) Microsoft Corporation.  All rights reserved. Licensed under the MIT License (the "License");
