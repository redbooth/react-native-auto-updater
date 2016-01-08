//
//  StatusBarNotification.h
//  AutoUpdate
//
//  Created by Rahul Jiresal on 11/24/15.
//  Copyright © 2015 Rahul Jiresal. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface StatusBarNotification : NSObject

+ (void)showWithMessage:(NSString*)message backgroundColor:(UIColor*)bgColor autoHide:(BOOL)autoHide;
+ (void)hide;
+ (UIColor*)errorColor;
+ (UIColor*)warningColor;
+ (UIColor*)successColor;
+ (UIColor*)infoColor;

@end
