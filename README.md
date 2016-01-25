# react-native-auto-updater

[![License](https://img.shields.io/cocoapods/l/ReactNativeAutoUpdater.svg?style=flat)](http://cocoapods.org/pods/ReactNativeAutoUpdater)
[![Platform](https://img.shields.io/cocoapods/p/ReactNativeAutoUpdater.svg?style=flat)](http://cocoapods.org/pods/ReactNativeAutoUpdater)

<img src="images/rnau.png" alt="React-Native Auto-Updater" width="400" />

## About

At [AeroFS](http://www.aerofs.com), we're close to shipping our first React Native app. Once the app is out, we would want to send updates over the air to bypass the sluggish AppStore review process, and speed up release cycles. We've built `react-native-auto-updater` to do just that. It was built as a part of our [2015 Thanksgiving Hackathon](https://www.aerofs.com/blog/how-we-run-hackathons/).

> **Does Apple permit this?**

>

> Yes! [Section 3.3.2 of the iOS Developer Program](https://developer.apple.com/programs/ios/information/iOS_Program_Information_4_3_15.pdf) allows it "provided that such scripts and code do not change the primary purpose of the Application by providing features or functionality that are inconsistent with the intended and advertised purpose of the Application."

React Native `jsbundle` can be easily over a couple of megabytes. On cellular connections, downloading them more often than what is needed is not a good idea. To tackle that problem, we need to decide if the bundle needs to be downloaded at all.

We solve this by shipping the app with an initial version of the `jsbundle`, this reduces the latency during the initial startup. Then we start querying for available update, and download the updated `jsbundle`. All subsequent runs of the app uses this updated bundle.

In order to decide whether to download the `jsbundle` or not, we need to know some *meta*-information about the bundle. For `react-native-auto-updater`, we store this *meta*-information as a form of a JSON file somewhere on the internet. The format of the JSON is as follows

``` json
{
	"version": "1.1.0",
	"minContainerVersion": "1.0",
	"url": {
      "url": "/s/3klfuwm74sfnj0w/main.jsbundle?raw=1",
      "isRelative": true
    }
}
```

Here's what the fields in the JSON mean:

* `version` — this is the version of the bundle file (in *major.minor.patch* format)
* `minContainerVersion` — this is the minimum version of the container (native) app that is allowed to download this bundle (this is needed because adding a new React Native component to your app might result into changed native app, hence, going through the AppStore review process)
* `url.url` — this is where `ReactNativeAutoUpdater` will download the JS bundle from
* `url.isRelative` — this tells if the provided URL is a relative URL (when set to `true`, you need to set the hostname by using the method `(void)setHostnameForRelativeDownloadURLs:(NSString*)hostname;`)

`react-native-auto-updater` needs know the location of this JSON file upon initialization.

## Screenshots

Here's a GIF'ed screencast of `react-native-auto-updater` in action.

![rn-auto-updater](https://cloud.githubusercontent.com/assets/216346/12154339/c0e6e432-b473-11e5-8aa9-29ef89029c08.gif)



## Installation

### iOS

1. `npm install react-native-auto-updater --save`
2. In the XCode's "Project navigator", right click on your project's Libraries folder ➜ Add Files to _"Your Project Name"_
3. Go to `node_modules` ➜ `react-native-image-picker` ➜ `iOS` ➜ select `ReactNativeAutoUpdater.xcodeproj`
4. In the Xcode Project Navigator, click the root project, and in `General` tab, look for `Linked Frameworks and Libraries`. Click on the `+` button at the bottom and add `libReactNativeAutoUpdater.a` from the list.
5. Go to `Build Settings` tab and search for `Header Search Paths`. In the list, add `$(SRCROOT)/../node_modules/react-native-auto-updater` and select `recursive`.

<img src="images/link_library.png" alt="Link Frameworks and Libraries" width="600" />


<img src="images/add_header.png" alt="Header Search Paths" width="600" />

### Android

Coming soon.



## Usage

### iOS

In your `AppDelegate.m` (make sure you complete step #5 from installation above, otherwise Xcode will not find the header file)

``` objective-c
#import "ReactNativeAutoUpdater.h"
```

The code below essentially follows these steps.

1. Get an instance of `ReactNativeAutoUpdater`
2. Set `self` as a `delegate`
3. Initialize with `updateMetadataUrl` , `defaultJSCodeLocation` and `defaultMetadataFileLocation`
4. Make a call to `checkUpdate`, `checkUpdateDaily` or `checkUpdateWeekly`
5. Don't forget to implement the delegate methods (optional)

``` objective-c
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  // defaultJSCodeLocation is needed at least for the first startup
  NSURL* defaultJSCodeLocation = [[NSBundle mainBundle] URLForResource:@"main" withExtension:@"jsbundle"];

  ReactNativeAutoUpdater* updater = [ReactNativeAutoUpdater sharedInstance];
  [updater setDelegate:self];

  // We set the location of the metadata file that has information about the JS Code that is shipped with the app.
  // This metadata is used to compare the shipped code against the updates.

  NSURL* defaultMetadataFileLocation = [[NSBundle mainBundle] URLForResource:@"metadata" withExtension:@"json"];
  [updater initializeWithUpdateMetadataUrl:[NSURL URLWithString:JS_CODE_METADATA_URL]
                     defaultJSCodeLocation:defaultJSCodeLocation
               defaultMetadataFileLocation:defaultMetadataFileLocation ];
  [updater setHostnameForRelativeDownloadURLs:@"https://www.aerofs.com"];
  [updater checkUpdate];

  NSURL* latestJSCodeLocation = [updater latestJSCodeLocation];

  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  UIViewController *rootViewController = [UIViewController new];
  self.window.rootViewController = rootViewController;
  RCTBridge* bridge = [[RCTBridge alloc] initWithBundleURL:url moduleProvider:nil launchOptions:nil];
    RCTRootView* rootView = [[RCTRootView alloc] initWithBridge:bridge moduleName:@"ReactNativeAutoUpdater" initialProperties:nil];
    self.window.rootViewController.view = rootView;
  [self.window makeKeyAndVisible];
  return YES;
}
```

If you want, you can ask the user to apply the update, right after an update is downloaded. To do that, implement the delegate methods. Check the Example app to see a working sample.

`react-native-auto-updater` is highly configurable. Here are the options you can configure

``` objective-c
ReactNativeAutoUpdater *updater = [ReactNativeAutoUpdater sharedInstance];
/* Show progress during the udpate 
 * default value - YES
 */
[updater showProgress: NO]; 

/* Allow use of cellular data to download the update 
 * default value - NO
 */
[updater allowCellularDataUse: YES];

/* Decide what type of updates to download
 * Available options - 
 *	ReactNativeAutoUpdaterMajorUpdate - will download only if major version number changes
 *	ReactNativeAutoUpdaterMinorUpdate - will download if major or minor version number changes
 *	ReactNativeAutoUpdaterPatchUpdate - will download for any version change
 * default value - ReactNativeAutoUpdaterMinorUpdate
 */
[updater downloadUpdatesForType: ReactNativeAutoUpdaterMajorUpdate];

/* Check update right now
*/
[updater checkUpdate];

/* Check update daily - Only check update once per day
*/
[updater checkUpdateDaily];

/* Check update weekly - Only check updates once per week
*/
[updater checkUpdatesWeekly];

/*  When the JSON file has a relative URL for downloading the JS Bundle,
 *  set the hostname for relative downloads
 */
[updater setHostnameForRelativeDownloadURLs:@"https://www.aerofs.com/"];

```



### Android

Coming soon.



### JS (optional, common for iOS and Android)

``` javascript
var ReactNativeAutoUpdater = require('react-native-auto-updater');

ReactNativeAutoUpdater.jsCodeVersion() 
// will give you the JS code version that is currently in use

```



#### Important

Don't forget to provide `react-native-auto-updater` with the metadata file for the JS code that is shipped with the app. Metadata in this file is used to compare the shipped JS code with updates. Thanks to [@arbesfeld](https://github.com/arbesfeld) for pointing out this bug.



## License

`react-native-auto-updater` is available under the MIT license. See the LICENSE file for more info.