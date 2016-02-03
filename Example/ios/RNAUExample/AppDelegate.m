/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "AppDelegate.h"

#import "RCTRootView.h"

#import "ReactNativeAutoUpdater.h"

#define JS_CODE_METADATA_URL @"https://www.dropbox.com/s/tc4jmkef48cmu87/update.json?raw=1"

@interface AppDelegate() <ReactNativeAutoUpdaterDelegate>

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  NSURL* defaultJSCodeLocation = [[NSBundle mainBundle] URLForResource:@"main" withExtension:@"jsbundle"];
  
  /**
   *  1. Get an instance of ReactNativeAutoUpdater
   *  2. Set self as a delegate.
   *  3. Initialize with MetadataUrl and defaultJSCodeLocation
   *  4. Make a call to checkUpdate
   *  5. Don't forget to implement the delegate methods
   */
  ReactNativeAutoUpdater* updater = [ReactNativeAutoUpdater sharedInstance];
  [updater setDelegate:self];
  NSURL* defaultMetadataFileLocation = [[NSBundle mainBundle] URLForResource:@"metadata" withExtension:@"json"];
  [updater initializeWithUpdateMetadataUrl:[NSURL URLWithString:JS_CODE_METADATA_URL]
                     defaultJSCodeLocation:defaultJSCodeLocation
               defaultMetadataFileLocation:defaultMetadataFileLocation ];
  
  [updater setHostnameForRelativeDownloadURLs:@"https://www.dropbox.com"];
  [updater checkUpdate];
  
  NSURL* latestJSCodeLocation = [updater latestJSCodeLocation];
  
  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  UIViewController *rootViewController = [UIViewController new];
  self.window.rootViewController = rootViewController;
  [self createReactRootViewFromURL:latestJSCodeLocation];
  [self.window makeKeyAndVisible];
  return YES;
}

- (void)createReactRootViewFromURL:(NSURL*)url {
  // Make sure this runs on main thread. Apple does not want you to change the UI from background thread.
  dispatch_async(dispatch_get_main_queue(), ^{
    RCTBridge* bridge = [[RCTBridge alloc] initWithBundleURL:url moduleProvider:nil launchOptions:nil];
    RCTRootView* rootView = [[RCTRootView alloc] initWithBridge:bridge moduleName:@"ReactNativeAutoUpdater" initialProperties:nil];
    self.window.rootViewController.view = rootView;
  });
}


#pragma mark - ReactNativeAutoUpdaterDelegate methods

- (void)ReactNativeAutoUpdater_updateDownloadedToURL:(NSURL *)url {
  UIAlertController *alertController = [UIAlertController
                                        alertControllerWithTitle:NSLocalizedString(@"Update Downloaded", nil)
                                        message:NSLocalizedString(@"An update was downloaded. Do you want to apply the update now?", nil)
                                        preferredStyle:UIAlertControllerStyleAlert];
  
  UIAlertAction *cancelAction = [UIAlertAction
                                 actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel action")
                                 style:UIAlertActionStyleCancel
                                 handler:^(UIAlertAction *action)
                                 {
                                   NSLog(@"Cancel action");
                                 }];
  
  UIAlertAction *okAction = [UIAlertAction
                             actionWithTitle:NSLocalizedString(@"OK", @"OK action")
                             style:UIAlertActionStyleDefault
                             handler:^(UIAlertAction *action)
                             {
                               [self createReactRootViewFromURL: url];
                             }];
  
  [alertController addAction:cancelAction];
  [alertController addAction:okAction];
  
  // make sure this runs on main thread. Apple doesn't like if you change UI from background thread.
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.window.rootViewController presentViewController:alertController animated:YES completion:nil];
  });
  
}

- (void)ReactNativeAutoUpdater_updateDownloadFailed {
  NSLog(@"Update failed to download");
}

@end
