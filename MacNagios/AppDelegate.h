//
//  AppDelegate.h
//  MacNagios
//
//  Created by Brad Peabody on 4/4/14.
//  Copyright (c) 2014 BGP. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSUserNotificationCenterDelegate>

@property (assign) IBOutlet NSWindow *window;
@property WebView *webView;
@property NSStatusItem *statusItem;
@property NSTimer *timer;
@property NSDictionary *configData; // data loaded from config plist
@property NSArray *checkResults; // the results of the checking
@property NSString *lastStatusString; // the last status string we had
@property NSDictionary *serviceStatusDict; // keep track of the last status of each service - so we can make a list of what changed
//@property NSMenu *menu;

@end
