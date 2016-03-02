//
//  ReactNativeAutoUpdater.m
//  ReactNativeAutoUpdater
//
//  Created by Rahul Jiresal on 11/23/15.
//  Copyright © 2015 Rahul Jiresal. All rights reserved.
//

#import "ReactNativeAutoUpdater.h"
#import "StatusBarNotification.h"
#import "RCTBridge.h"

NSString* const ReactNativeAutoUpdaterLastUpdateCheckDate = @"ReactNativeAutoUpdater Last Update Check Date";
NSString* const ReactNativeAutoUpdaterCurrentJSCodeMetadata = @"ReactNativeAutoUpdater Current JS Code Metadata";

@interface ReactNativeAutoUpdater() <NSURLSessionDownloadDelegate, RCTBridgeModule>

@property NSURL* defaultJSCodeLocation;
@property NSURL* defaultMetadataFileLocation;
@property NSURL* _latestJSCodeLocation;
@property NSURL* metadataUrl;
@property BOOL showProgress;
@property BOOL allowCellularDataUse;
@property NSString* hostname;
@property ReactNativeAutoUpdaterUpdateType updateType;
@property NSDictionary* updateMetadata;
@property BOOL initializationOK;

@end

@implementation ReactNativeAutoUpdater

RCT_EXPORT_MODULE()

static ReactNativeAutoUpdater *RNAUTOUPDATER_SINGLETON = nil;
static bool isFirstAccess = YES;

+ (id)sharedInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        isFirstAccess = NO;
        RNAUTOUPDATER_SINGLETON = [[super allocWithZone:NULL] init];
        [RNAUTOUPDATER_SINGLETON defaults];
    });
    
    return RNAUTOUPDATER_SINGLETON;
}

#pragma mark - Life Cycle

+ (id) allocWithZone:(NSZone *)zone {
    return [self sharedInstance];
}

+ (id)copyWithZone:(struct _NSZone *)zone {
    return [self sharedInstance];
}

+ (id)mutableCopyWithZone:(struct _NSZone *)zone {
    return [self sharedInstance];
}

- (id)copy {
    return [[ReactNativeAutoUpdater alloc] init];
}

- (id)mutableCopy {
    return [[ReactNativeAutoUpdater alloc] init];
}

- (id) init {
    if(RNAUTOUPDATER_SINGLETON){
        return RNAUTOUPDATER_SINGLETON;
    }
    if (isFirstAccess) {
        [self doesNotRecognizeSelector:_cmd];
    }
    self = [super init];
    return self;
}

- (void)defaults {
    self.showProgress = YES;
    self.allowCellularDataUse = NO;
    self.updateType = ReactNativeAutoUpdaterMinorUpdate;
}

#pragma mark - JS methods

- (NSDictionary *)constantsToExport {
    NSDictionary* metadata = [[NSUserDefaults standardUserDefaults] objectForKey:ReactNativeAutoUpdaterCurrentJSCodeMetadata];
    NSString* version = @"";
    if (metadata) {
        version = [metadata objectForKey:@"version"];
    }
    return @{
            @"jsCodeVersion": version
        };
}

#pragma mark - initialize Singleton

- (void)initializeWithUpdateMetadataUrl:(NSURL*)url defaultJSCodeLocation:(NSURL*)defaultJSCodeLocation defaultMetadataFileLocation:(NSURL*)metadataFileLocation {
    self.metadataUrl = url;
    self.defaultJSCodeLocation = defaultJSCodeLocation;
    self.defaultMetadataFileLocation = metadataFileLocation;
    
    [self compareSavedMetadataAgainstContentsOfFile: self.defaultMetadataFileLocation];
}

- (void)showProgress: (BOOL)progress {
    self.showProgress = progress;
}

- (void)allowCellularDataUse: (BOOL)cellular {
    self.allowCellularDataUse = cellular;
}

- (void)downloadUpdatesForType:(ReactNativeAutoUpdaterUpdateType)type {
    self.updateType = type;
}

- (NSURL*)latestJSCodeLocation {
    NSString* latestJSCodeURLString = [[[self libraryDirectory] stringByAppendingPathComponent:@"JSCode"] stringByAppendingPathComponent:@"main.jsbundle"];
    if (latestJSCodeURLString && [[NSFileManager defaultManager] fileExistsAtPath:latestJSCodeURLString]) {
        self._latestJSCodeLocation = [NSURL URLWithString:[NSString stringWithFormat:@"file://%@", latestJSCodeURLString]];
    }
    return self._latestJSCodeLocation ? self._latestJSCodeLocation : self.defaultJSCodeLocation;
}

- (void)setHostnameForRelativeDownloadURLs:(NSString *)hostname {
    self.hostname = hostname;
}

- (void)compareSavedMetadataAgainstContentsOfFile: (NSURL*)metadataFileLocation {
    NSData* fileMetadata = [NSData dataWithContentsOfURL: metadataFileLocation];
    if (!fileMetadata) {
        NSLog(@"[ReactNativeAutoUpdater]: Make sure you initialize RNAU with a metadata file.");
        if (self.showProgress) {
            [StatusBarNotification showWithMessage:NSLocalizedString(@"Error reading Metadata File.", nil) backgroundColor:[StatusBarNotification errorColor] autoHide:YES];
        }
        self.initializationOK = NO;
        return;
    }
    NSError *error;
    NSDictionary* localMetadata = [NSJSONSerialization JSONObjectWithData:fileMetadata options:NSJSONReadingAllowFragments error:&error];
    if (error) {
        NSLog(@"[ReactNativeAutoUpdater]: Initialized RNAU with a WRONG metadata file.");
        if (self.showProgress) {
            [StatusBarNotification showWithMessage:NSLocalizedString(@"Error reading Metadata File.", nil) backgroundColor:[StatusBarNotification errorColor] autoHide:YES];
        }
        self.initializationOK = NO;
        return;
    }
    NSDictionary* savedMetadata = [[NSUserDefaults standardUserDefaults] objectForKey:ReactNativeAutoUpdaterCurrentJSCodeMetadata];
    if (!savedMetadata) {
        [[NSUserDefaults standardUserDefaults] setObject:localMetadata forKey:ReactNativeAutoUpdaterCurrentJSCodeMetadata];
    }
    else {
        if ([[savedMetadata objectForKey:@"version"] compare:[localMetadata objectForKey:@"version"] options:NSNumericSearch] == NSOrderedAscending) {
            NSData* data = [NSData dataWithContentsOfURL:self.defaultJSCodeLocation];
            NSString* filename = [NSString stringWithFormat:@"%@/%@", [self createCodeDirectory], @"main.jsbundle"];
            
            if ([data writeToFile:filename atomically:YES]) {
                [[NSUserDefaults standardUserDefaults] setObject:localMetadata forKey:ReactNativeAutoUpdaterCurrentJSCodeMetadata];
            }
        }
    }
    self.initializationOK = YES;
}

#pragma mark - Check updates

- (void)performUpdateCheck {
    if (!self.initializationOK) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.showProgress) {
            [StatusBarNotification showWithMessage:NSLocalizedString(@"Checking for update.", nil) backgroundColor:[StatusBarNotification infoColor] autoHide:YES];
        }
    });
    NSData* data = [NSData dataWithContentsOfURL:self.metadataUrl];
    if (!data) {
        if (self.showProgress) {
            [StatusBarNotification showWithMessage:NSLocalizedString(@"Received no Update Metadata. Aborted.", nil) backgroundColor:[StatusBarNotification errorColor] autoHide:YES];
        }
        return;
    }
    NSError* error;
    self.updateMetadata = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
    if (error) {
        if (self.showProgress) {
            [StatusBarNotification showWithMessage:NSLocalizedString(@"Error reading Metadata JSON. Update aborted.", nil) backgroundColor:[StatusBarNotification errorColor] autoHide:YES];
        }
        return;
    }
    NSString* versionToDownload = [self.updateMetadata objectForKey:@"version"];
    NSString* urlToDownload = [[self.updateMetadata objectForKey:@"url"] objectForKey:@"url"];
    NSString* minContainerVersion = [self.updateMetadata objectForKey:@"minContainerVersion"];
    BOOL isRelative = [[[self.updateMetadata objectForKey:@"url"] objectForKey:@"isRelative"] boolValue];
    
    if ([self shouldDownloadUpdateWithVersion:versionToDownload forMinContainerVersion:minContainerVersion]) {
        if (self.showProgress) {
            [StatusBarNotification showWithMessage:NSLocalizedString(@"Downloading Update.", nil) backgroundColor:[StatusBarNotification infoColor] autoHide:YES];
        }
        if (isRelative) {
            urlToDownload = [self.hostname stringByAppendingString:urlToDownload];
        }
        [self startDownloadingUpdateFromURL:urlToDownload];
    }
    else {
        if (self.showProgress) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [StatusBarNotification showWithMessage:NSLocalizedString(@"Already Up to Date.", nil) backgroundColor:[StatusBarNotification successColor] autoHide:YES];
            });
        }
    }
}

- (BOOL)shouldDownloadUpdateWithVersion:(NSString*)version forMinContainerVersion:(NSString*)minContainerVersion {
    BOOL shouldDownload = NO;
    
    /*
     * First check for the version match. If we have the update version, then don't download.
     * Also, check what kind of updates the user wants.
     */
    NSDictionary* currentMetadata = [[NSUserDefaults standardUserDefaults] objectForKey:ReactNativeAutoUpdaterCurrentJSCodeMetadata];
    if (!currentMetadata) {
        shouldDownload = YES;
    }
    else {
        NSString* currentVersion = [currentMetadata objectForKey:@"version"];
        
        int currentMajor, currentMinor, currentPatch, updateMajor, updateMinor, updatePatch;
        NSArray* currentComponents = [currentVersion componentsSeparatedByString:@"."];
        if (currentComponents.count == 0) {
            return NO;
        }
        currentMajor = [currentComponents[0] intValue];
        if (currentComponents.count >= 2) {
            currentMinor = [currentComponents[1] intValue];
        }
        else {
            currentMinor = 0;
        }
        if (currentComponents.count >= 3) {
            currentPatch = [currentComponents[2] intValue];
        }
        else {
            currentPatch = 0;
        }
        NSArray* updateComponents = [version componentsSeparatedByString:@"."];
        updateMajor = [updateComponents[0] intValue];
        if (updateComponents.count >= 2) {
            updateMinor = [updateComponents[1] intValue];
        }
        else {
            updateMinor = 0;
        }
        if (updateComponents.count >= 3) {
            updatePatch = [updateComponents[2] intValue];
        }
        else {
            updatePatch = 0;
        }
        
        switch (self.updateType) {
            case ReactNativeAutoUpdaterMajorUpdate: {
                if (currentMajor < updateMajor) {
                    shouldDownload = YES;
                }
                break;
            }
            case ReactNativeAutoUpdaterMinorUpdate: {
                if (currentMajor < updateMajor || (currentMajor == updateMajor && currentMinor < updateMinor)) {
                    shouldDownload = YES;
                }
                
                break;
            }
            case ReactNativeAutoUpdaterPatchUpdate: {
                if (currentMajor < updateMajor || (currentMajor == updateMajor && currentMinor < updateMinor)
                    || (currentMajor == updateMajor && currentMinor == updateMinor && currentPatch < updatePatch)) {
                    shouldDownload = YES;
                }
                break;
            }
            default: {
                shouldDownload = YES;
                break;
            }
        }
    }
    
    /*
     * Then check if the update is good for our container version.
     */
    NSString* containerVersion = [self containerVersion];
    if (shouldDownload && [containerVersion compare:minContainerVersion options:NSNumericSearch] != NSOrderedAscending) {
        shouldDownload = YES;
    }
    else {
        shouldDownload = NO;
    }
    
    return shouldDownload;
}

- (void)checkUpdate {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.metadataUrl) {
            [self performUpdateCheck];
            [self setLastUpdateCheckPerformedOnDate: [NSDate date]];
        }
        else {
            NSLog(@"[ReactNativeAutoUpdater]: Please make sure you have set the Update Metadata URL");
        }
    });
}

- (void)checkUpdateDaily {
    /*
     On app's first launch, lastVersionCheckPerformedOnDate isn't set.
     Avoid false-positive fulfilment of second condition in this method.
     Also, performs version check on first launch.
     */
    if (![self lastUpdateCheckPerformedOnDate]) {
        [self checkUpdate];
    }
    
    // If daily condition is satisfied, perform version check
    if ([self numberOfDaysElapsedBetweenLastVersionCheckDate] > 1) {
        [self checkUpdate];
    }
}

- (void)checkUpdateWeekly {
    /*
     On app's first launch, lastVersionCheckPerformedOnDate isn't set.
     Avoid false-positive fulfilment of second condition in this method.
     Also, performs version check on first launch.
     */
    if (![self lastUpdateCheckPerformedOnDate]) {
        [self checkUpdate];
    }
    
    // If weekly condition is satisfied, perform version check
    if ([self numberOfDaysElapsedBetweenLastVersionCheckDate] > 7) {
        [self checkUpdate];
    }
}


#pragma mark - private

- (void)startDownloadingUpdateFromURL:(NSString*)urlString {
    NSURL* url = [NSURL URLWithString:urlString];
    
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    sessionConfig.allowsCellularAccess = self.allowCellularDataUse;
    sessionConfig.timeoutIntervalForRequest = 60.0;
    sessionConfig.timeoutIntervalForResource = 60.0;
    sessionConfig.HTTPMaximumConnectionsPerHost = 1;
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig
                                                          delegate:self
                                                     delegateQueue:nil];
    
    NSURLSessionDownloadTask* task = [session downloadTaskWithURL:url];
    [task resume];
}

- (NSUInteger)numberOfDaysElapsedBetweenLastVersionCheckDate {
    NSCalendar *currentCalendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [currentCalendar components:NSCalendarUnitDay
                                                      fromDate:[self lastUpdateCheckPerformedOnDate]
                                                        toDate:[NSDate date]
                                                       options:0];
    return [components day];
}

- (NSDate*)lastUpdateCheckPerformedOnDate {
    return [[NSUserDefaults standardUserDefaults] objectForKey:ReactNativeAutoUpdaterLastUpdateCheckDate];
}

- (void)setLastUpdateCheckPerformedOnDate: date {
    [[NSUserDefaults standardUserDefaults] setObject:date forKey:ReactNativeAutoUpdaterLastUpdateCheckDate];
}

- (NSString*)containerVersion {
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
}

- (NSString*)libraryDirectory {
    return [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
}

- (NSString*)createCodeDirectory {
    NSString* libraryDirectory = [self libraryDirectory];
    NSString *filePathAndDirectory = [libraryDirectory stringByAppendingPathComponent:@"JSCode"];
    NSError *error;
    
    NSFileManager* fileManager = [NSFileManager defaultManager];
    
    BOOL isDir;
    if ([fileManager fileExistsAtPath:filePathAndDirectory isDirectory:&isDir]) {
        if (isDir) {
            return filePathAndDirectory;
        }
    }
    
    if (![fileManager createDirectoryAtPath:filePathAndDirectory
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:&error])
    {
        NSLog(@"Create directory error: %@", error);
        return nil;
    }
    return filePathAndDirectory;
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    if (totalBytesExpectedToWrite == NSURLSessionTransferSizeUnknown) {
        if (self.showProgress) {
            [StatusBarNotification showWithMessage:[NSString stringWithFormat:NSLocalizedString(@"Downloading Update - %@", nil),
                                                    [NSByteCountFormatter stringFromByteCount:totalBytesWritten
                                                                                   countStyle:NSByteCountFormatterCountStyleFile]]
                                   backgroundColor:[StatusBarNotification infoColor]
                                          autoHide:NO];
        }
    }
    else {
        if (self.showProgress) {
            [StatusBarNotification showWithMessage:[NSString stringWithFormat:NSLocalizedString(@"Downloading Update - %d%%", nil), (int)(totalBytesWritten/totalBytesExpectedToWrite) * 100]
                                   backgroundColor:[StatusBarNotification infoColor]
                                          autoHide:NO];
        }
    }
}

-(void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    if (self.showProgress) {
        [StatusBarNotification showWithMessage:NSLocalizedString(@"Download Complete.", nil)
                               backgroundColor:[StatusBarNotification successColor]
                                      autoHide:YES];
    }
    NSError* error;
    
    NSData* data = [NSData dataWithContentsOfURL:location];
    NSString* filename = [NSString stringWithFormat:@"%@/%@", [self createCodeDirectory], @"main.jsbundle"];
    
    if ([data writeToFile:filename atomically:YES]) {
        [[NSUserDefaults standardUserDefaults] setObject:self.updateMetadata forKey:ReactNativeAutoUpdaterCurrentJSCodeMetadata];
      if ([self.delegate respondsToSelector:@selector(ReactNativeAutoUpdater:updateDownloadedToURL:currentVersion:)]) {
        NSString* currentVersion = self.updateMetadata[@"version"];
        [self.delegate ReactNativeAutoUpdater:self updateDownloadedToURL:[NSURL URLWithString:[NSString stringWithFormat:@"file://%@", filename]] currentVersion:currentVersion];
      }
    }
    else {
        NSLog(@"[ReactNativeAutoUpdater]: Update save failed - %@.", error.localizedDescription);
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        NSLog(@"[ReactNativeAutoUpdater]: %@", error.localizedDescription);
      if ([self.delegate respondsToSelector:@selector(ReactNativeAutoUpdater:updateDownloadFailed:)]) {
        [self.delegate ReactNativeAutoUpdater:self updateDownloadFailed:error];
      }
    }
}

@end
