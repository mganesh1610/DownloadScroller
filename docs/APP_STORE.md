# Mac App Store preparation

DownloadScroller 0.1.0 is an early preview. The source and native project are prepared for an App Store workflow; the app has **not** been submitted, approved, or published on the Mac App Store.

## What is already included

- Native macOS Xcode application target, shared scheme, and universal architecture configuration.
- App Sandbox with user-selected **read-only** access and app-scoped bookmarks.
- Public AppKit, SwiftUI, Foundation, Quick Look, and Uniform Type Identifiers APIs.
- App icon at all required traditional macOS icon sizes.
- Privacy manifest declaring no tracking or collection, plus required reasons for preferences and file metadata.
- MIT source license, public privacy policy, support channel, and draft store listing below.

The application does not patch the Dock, use private APIs, inject code, request Accessibility or Full Disk Access, or require an administrator. It does not add itself to the Dock or configure login items automatically. The Dock icon is the app's normal running-app icon.

## Publisher steps

1. Enroll in the [Apple Developer Program](https://developer.apple.com/programs/enroll/). Apple lists membership at USD 99 per year or the applicable local price; eligible fee waivers may apply. Enrollment and agreements must be completed by the account owner.
2. Install a currently supported full version of Xcode. Add your Apple account in Xcode, open `DownloadScroller.xcodeproj`, and select your team under **Signing & Capabilities**. Register an available bundle ID; the checked-in default is `io.github.mganesh1610.DownloadScroller`.
3. Test the signed sandboxed app on the minimum supported macOS version and on current macOS, including Intel hardware if that architecture remains in the release. Complete the manual cases in [VALIDATION.md](VALIDATION.md). Check VoiceOver, keyboard-only use, Reduce Motion, multiple displays, Dock positions, sleep/wake, and unavailable folders.
4. In App Store Connect, create the macOS app record, choose pricing and availability, complete the age-rating and export-compliance questions, and add the privacy/support URLs. The publisher must verify legal and account-specific answers.
5. Select **Any Mac**, then **Product → Archive**. In Organizer, choose **Distribute App → App Store Connect** and validate/upload using your team. Do not submit the ad-hoc `dist/` bundle produced by the local build script.
6. Test the processed build through TestFlight, add actual screenshots and the review notes below, and submit the complete version for review. Apple's review determines acceptance.

For a command-line archive after signing is configured:

```sh
xcodebuild -project DownloadScroller.xcodeproj -scheme DownloadScroller \
  -configuration Release -destination 'generic/platform=macOS' \
  -archivePath build/DownloadScroller.xcarchive \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID -allowProvisioningUpdates archive
```

No signing identity, profile, account credentials, or team ID is stored in this repository.

## Draft store listing

**Name:** DownloadScroller  
**Subtitle:** A scrollable fan for your files  
**Primary category:** Utilities  
**Suggested secondary category:** Productivity  
**Version:** 0.1.0 (change to a release version when ready)  
**Support URL:** https://github.com/mganesh1610/DownloadScroller/issues  
**Privacy URL:** https://github.com/mganesh1610/DownloadScroller/blob/main/PRIVACY.md

**Promotional text**

Give your Downloads room to breathe. Scroll a familiar file fan, find what you need, and preview it without losing your place.

**Description**

DownloadScroller puts a scrollable file fan a click away in your Dock and menu bar.

Choose your Downloads folder or another folder you use often. Browse every visible file in a continuous scroll, switch to a compact list, and find items by name or type. Sort by newest, oldest, name, size, or kind. Preview supported files with Quick Look, open them in their usual apps, or reveal them in Finder.

New files appear as the folder changes. Your selected folder is remembered between launches. Keyboard navigation, search shortcuts, and a pin option help you keep things close at hand.

DownloadScroller works locally, with read-only folder access. No account, advertising, or analytics. Its source code is available under the MIT license.

DownloadScroller is a standalone utility that opens from its own app icon. It does not change Apple's built-in Downloads stack.

**Keywords:** downloads,files,fan,scroll,folder,dock,menu bar,quick look,organize,finder

## Review notes

On launch, select **Choose Downloads folder** and grant read-only access to Downloads or a test folder through the standard macOS picker. No login is needed. Alternatively, select **Take a look with sample files** to browse 240 generated files in the app's temporary directory.

Scroll in the fan to reach all files. Use the search field, filter buttons, sort menu, or fan/list toggle. Click a file to open it. Use arrow keys and Space (or Command-Y) for Quick Look, or right-click a file for actions. Use the app's menu bar item or click its normal Dock icon to reopen the panel. Command-Q quits the app. **… → Disconnect folder** removes saved folder access.

This app provides its own window using public APIs. It does not modify the system Dock or the built-in Downloads stack. The bookmark entitlement persists the folder the user chose; read-only access supports enumeration, metadata, thumbnails, and previews.

## Privacy questionnaire preparation

For the code currently in this repository, the intended App Privacy answer is **Data Not Collected**. The app contains no analytics SDK or network entitlement. Review Apple's definition and the actual release binary before answering. A privacy manifest is included; it does not replace App Store Connect's privacy questionnaire.

## Screenshots to prepare

Use actual app captures with generated sample files, with no personal downloads visible. Show the fan with many files, search results, list view, and Quick Look. The development screenshots in this repository are review aids; prepare store uploads at Apple's current accepted dimensions. Do not claim that the app changes the native Dock stack.

## Apple references

- [Review guidelines: Mac App Store requirements and public APIs](https://developer.apple.com/app-store/review/guidelines/)
- [Configuring App Sandbox](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox)
- [App-scoped security bookmarks](https://developer.apple.com/documentation/professional-video-applications/enabling-security-scoped-bookmark-and-url-access)
- [Required-reason APIs](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)
- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)
- [Developer membership details](https://developer.apple.com/programs/whats-included/)
