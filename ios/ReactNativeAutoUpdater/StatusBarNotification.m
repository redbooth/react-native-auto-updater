//
//  StatusBarNotification.m
//  AutoUpdate
//
//  Created by Rahul Jiresal on 11/24/15.
//  Copyright © 2015 Rahul Jiresal. All rights reserved.
//

#import "StatusBarNotification.h"

@interface StatusBarNotification ()

@property (strong, nonatomic) UIWindow* notificationWindow;
@property (strong, nonatomic) UILabel* notificationLabel;
@property BOOL currentlyShowing;
@property NSTimer *timer;
@property NSMutableArray *messageQueue;

@end

@implementation StatusBarNotification

static StatusBarNotification *STATUSBARNOTIFICATION_SINGLETON = nil;
static bool isFirstAccess = YES;

+ (id)sharedInstance
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    isFirstAccess = NO;
    STATUSBARNOTIFICATION_SINGLETON = [[super allocWithZone:NULL] init];
  });
  
  return STATUSBARNOTIFICATION_SINGLETON;
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
  return [[StatusBarNotification alloc] init];
}

- (id)mutableCopy {
  return [[StatusBarNotification alloc] init];
}

- (id) init {
  if(STATUSBARNOTIFICATION_SINGLETON){
    return STATUSBARNOTIFICATION_SINGLETON;
  }
  if (isFirstAccess) {
    [self doesNotRecognizeSelector:_cmd];
  }
  self = [super init];
  return self;
}


+ (void)showWithMessage:(NSString*)message backgroundColor:(UIColor*)bgColor autoHide:(BOOL)autoHide {
  [[StatusBarNotification sharedInstance] showWithMessage:message backgroundColor:bgColor autoHide:(BOOL)autoHide];
}

+ (void)hide {
  [[StatusBarNotification sharedInstance] hideAnimated:YES];
}

+ (UIColor*)errorColor {
  return [UIColor colorWithRed:249.0/255.0 green:83.0/255.0 blue:114.0/255.0 alpha:1.0];
}

+ (UIColor*)warningColor {
  return [UIColor colorWithRed:255.0/255.0 green:153.0/255.0 blue:0.0/255.0 alpha:1.0];
}

+ (UIColor*)successColor {
  return [UIColor colorWithRed:29.0/255.0 green:156.0/255.0 blue:90.0/255.0 alpha:1.0];
}

+ (UIColor*)infoColor {
  return [UIColor colorWithRed:102.0/255.0 green:178.0/255.0 blue:255.0/255.0 alpha:1.0];
}


- (void)showWithMessage:(NSString*)message backgroundColor:(UIColor*)bgColor autoHide:(BOOL)autoHide{
  dispatch_async(dispatch_get_main_queue(), ^{
    if (self.currentlyShowing) {
      [self.timer invalidate];
      [self.notificationWindow setBackgroundColor:bgColor];
      [self.notificationLabel setText:message];
    }
    else {
      if (!self.notificationWindow) {
        self.notificationWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, -[UIApplication sharedApplication].statusBarFrame.size.height, [[UIScreen mainScreen] bounds].size.width, [UIApplication sharedApplication].statusBarFrame.size.height)];
        [self.notificationWindow setWindowLevel:UIWindowLevelStatusBar + 10];
        self.notificationLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width, [UIApplication sharedApplication].statusBarFrame.size.height)];
        [self.notificationLabel setTextAlignment:NSTextAlignmentCenter];
        [self.notificationLabel setTextColor:[UIColor whiteColor]];
        [self.notificationLabel setFont:[UIFont systemFontOfSize:12.0]];
        [self.notificationWindow addSubview:self.notificationLabel];
      }
      
      [self.notificationWindow setBackgroundColor:bgColor];
      [self.notificationLabel setText:message];
      [self.notificationWindow setHidden:NO];
      
      [UIView animateWithDuration:0.1 animations:^{
        [self.notificationWindow setFrame:CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width, [UIApplication sharedApplication].statusBarFrame.size.height)];
      }];
      self.currentlyShowing = YES;
    }
    if (autoHide) {
      self.timer = [NSTimer timerWithTimeInterval:0.7 target:self selector:@selector(timerTick) userInfo:nil repeats:NO];
      [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    }
  });

}

- (void)timerTick {
  self.currentlyShowing = NO;
  [self hideAnimated:YES];
}

- (void)hideAnimated:(BOOL)animated {
  dispatch_async(dispatch_get_main_queue(), ^{
    if (animated) {
      [UIView animateWithDuration:0.1 animations:^{
        [self.notificationWindow setFrame:CGRectMake(0, -[UIApplication sharedApplication].statusBarFrame.size.height, [[UIScreen mainScreen] bounds].size.width, [UIApplication sharedApplication].statusBarFrame.size.height)];
      } completion:^(BOOL finished) {
        [self.notificationWindow setHidden:YES];
      }];
    }
    else {
      [self.notificationWindow setHidden:YES];
      [self.notificationWindow setFrame:CGRectMake(0, -[UIApplication sharedApplication].statusBarFrame.size.height, [[UIScreen mainScreen] bounds].size.width, [UIApplication sharedApplication].statusBarFrame.size.height)];
    }
    self.currentlyShowing = NO;
  });
}

@end