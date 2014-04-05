//
//  AppDelegate.m
//  NagiosDock2
//
//  Created by Brad Peabody on 4/3/14.
//  Copyright (c) 2014 BGP. All rights reserved.
//

#import "AppDelegate.h"
#include <CoreFoundation/CFBundle.h>
#include <ApplicationServices/ApplicationServices.h>

@implementation AppDelegate

- (void)openURL:(NSString *)u {
    
    const char *b = [u UTF8String];
    int len = (int)strlen(b);
    
    CFURLRef url = CFURLCreateWithBytes (
                                         NULL,                        // allocator
                                         (UInt8*)b,     // URLBytes
                                         len,            // length
                                         kCFStringEncodingUTF8,      // encoding
                                         NULL                         // baseURL
                                         );
    LSOpenCFURLRef(url,0);
    CFRelease(url);
}

- (void)menuClickHandler:(id)arg {
    NSLog(@"menuClickHandler: %@", arg);
    
    if (arg == nil) {
        NSLog(@"Got nil arg, can't do nothin with that");
        return;
    }
    
    NSMenuItem *mi = arg;
    NSInteger idx = [mi tag];
    if (idx >= 0) {
        NSDictionary *result = [self.checkResults objectAtIndex:idx];
        NSDictionary *server = [result objectForKey:@"_server"];
        NSString *adminUrl = [server objectForKey:@"AdminURL"];
        if (adminUrl != nil) {
            [self openURL:adminUrl];
        }
    }
    
    
}
- (void)quitHandler:(id)arg {
    NSLog(@"quitHandler");
    [NSApp terminate:self];
    
}

// Perform an update of the UI elements based on the latest checkResults
- (void)doUIUpdate:(id)arg {
    NSLog(@"doUIUpdate");
    
    
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"MacNagios"];
    //    [menu insertItemWithTitle:@"Test1" action:@selector(exampleHandler:) keyEquivalent:@"test1" atIndex:0];
    
    // totals
    int okCount = 0;
    int warnCount = 0;
    int critCount = 0;
    int unkCount = 0;
    int totalCount = 0;
    
    for (int i = 0; i < [self.checkResults count]; i++) {
        NSDictionary *resultDict = [self.checkResults objectAtIndex:i];
        NSString *entryName = [resultDict objectForKey:@"_name"];
        if ([resultDict objectForKey:@"_error"] == nil) {
            NSNumber *okCountNum = [resultDict objectForKey:@"okCount"];
            okCount += [okCountNum intValue];
            NSNumber *warnCountNum = [resultDict objectForKey:@"warnCount"];
            warnCount += [warnCountNum intValue];
            NSNumber *critCountNum = [resultDict objectForKey:@"critCount"];
            critCount += [critCountNum intValue];
            NSNumber *unkCountNum = [resultDict objectForKey:@"unkCount"];
            unkCount += [unkCountNum intValue];
            NSNumber *totalCountNum = [resultDict objectForKey:@"totalCount"];
            totalCount += [totalCountNum intValue];
            
            NSString *thisStr = [NSString stringWithFormat:@"%@: %d OK, %d Warn, %d Crit",
                                 entryName,
                                 [okCountNum intValue],
                                 [warnCountNum intValue],
                                 [critCountNum intValue]
                                 ];
            
            [[menu addItemWithTitle:thisStr action:@selector(menuClickHandler:) keyEquivalent:[NSString stringWithFormat:@"%d", i+1]] setTag:i];
            
        }
    }
    
    NSString *str = [NSString stringWithFormat:@" %d OK, %d Warn, %d Crit", okCount, warnCount, critCount];
    
    [self.statusItem setTitle: str];
    
    if (totalCount < 1) {  // something wrong if there are no services at all
        [self.statusItem setImage: [NSImage imageNamed:@"nagios-icon-smaller-orange.png"]];
    } else if (critCount > 0) {
        [self.statusItem setImage: [NSImage imageNamed:@"nagios-icon-smaller-red.png"]];
    } else if (unkCount > 0) {
        [self.statusItem setImage: [NSImage imageNamed:@"nagios-icon-smaller-orange.png"]];
    } else if (warnCount > 0) {
        [self.statusItem setImage: [NSImage imageNamed:@"nagios-icon-smaller-yellow.png"]];
    } else { // okCount > 0
        [self.statusItem setImage: [NSImage imageNamed:@"nagios-icon-smaller-green.png"]];
    }
    
    [self.statusItem setHighlightMode:YES];
    
    // add the end of the menu
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Quit" action:@selector(quitHandler:) keyEquivalent:@"quit"];
    
    [self.statusItem setMenu:menu];
    
    if (![self.lastStatusString isEqualToString:str]) {
        
        [self setLastStatusString:str]; // update status
        
        NSNumber *notifyOnChange = [self.configData objectForKey:@"NotifyOnChange"];
        NSNumber *notifyWithSound = [self.configData objectForKey:@"NotifyWithSound"];
        
        if ([notifyOnChange intValue]) {
            
            // send notification
            NSUserNotification *notification = [[NSUserNotification alloc] init];
            notification.title = @"Nagios Status Change";
            notification.informativeText = str;
            
            if ([notifyWithSound intValue]) {
                notification.soundName = NSUserNotificationDefaultSoundName;
            }
            
            [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
        }
        
        
    }
    
}

// called by timer to do the polling work
- (void)timeoutHandler:(id)arg {
    
    // not sure if this 100% safe or if it's needed, but for our purposes should be fine
    static volatile BOOL inHere = NO;
    if (inHere) { return; }
    inHere = YES;
    
    NSLog(@"timeoutHandler");
    
    NSArray *serversArray = [self.configData valueForKey:@"Servers"];
    
    NSMutableArray *results = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < [serversArray count]; i++) {
        NSDictionary *server = [serversArray objectAtIndex:i];
        NSString *urlStr = [server objectForKey:@"URL"];
        NSString *username = [server objectForKey:@"Username"];
        NSString *password = [server objectForKey:@"Password"];
        
        // Prepare the link that is going to be used on the GET request
        NSURL * url = [[NSURL alloc] initWithString:urlStr];
        
        // Prepare the request object
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url
                                                                  cachePolicy:NSURLRequestReturnCacheDataElseLoad
                                                              timeoutInterval:30];
        
        if (username != nil && [username length] > 0) {
            NSString *authStr = [NSString stringWithFormat:@"%@:%@", username, password];
            NSData *authData = [authStr dataUsingEncoding:NSUTF8StringEncoding];
            NSString *authValue = [NSString stringWithFormat:@"Basic %@", [authData base64EncodedStringWithOptions:0]];
            [urlRequest setValue:authValue forHTTPHeaderField:@"Authorization"];
        }
        
        // Prepare the variables for the JSON response
        NSData *urlData;
        NSURLResponse *response;
        NSError *error;
        
        // Make synchronous request
        urlData = [NSURLConnection sendSynchronousRequest:urlRequest
                                        returningResponse:&response
                                                    error:&error];
        
        if (error != nil) {
            NSLog(@"Error while getting URL %@: %@", url, error);
            NSLog(@"urlData: %@", [[NSString alloc] initWithData:urlData encoding:NSUTF8StringEncoding]);
            
            // add empty dictionary
            NSMutableDictionary *errorDict = [[NSMutableDictionary alloc] init];
            [errorDict setObject:@"error getting URL" forKey:@"_error"];
            [errorDict setObject:[server objectForKey:@"Name"] forKey:@"_name"];
            [errorDict setObject:server forKey:@"_server"];
            [results addObject:errorDict];
            
            continue;
        }
        
        // Construct a Array around the Data from the response
        NSDictionary* object = [NSJSONSerialization
                                JSONObjectWithData:urlData
                                options:0
                                error:&error];
        
        
        int okCount = 0;
        int warnCount = 0;
        int critCount = 0;
        int unkCount = 0;
        int totalCount = 0;
        
        
        NSDictionary* hosts = [object objectForKey:@"services"];
        
        if (hosts == nil) {
            // add empty dictionary
            NSMutableDictionary *errorDict = [[NSMutableDictionary alloc] init];
            [errorDict setObject:@"no 'services' entry, can't parse" forKey:@"_error"];
            [errorDict setObject:[server objectForKey:@"Name"] forKey:@"_name"];
            [errorDict setObject:server forKey:@"_server"];
            [results addObject:errorDict];
            
            continue;
        }
        
        // each individual host
        NSEnumerator *hostEnumerator = [hosts keyEnumerator];
        NSString *hostKey;
        while (hostKey = [hostEnumerator nextObject]) {
            
            NSDictionary *hostDict = [hosts objectForKey:hostKey];
            
            NSEnumerator *serviceEnumerator = [hostDict keyEnumerator];
            NSString *serviceKey;
            while (serviceKey = [serviceEnumerator nextObject]) {
                
                NSDictionary *serviceDict = [hostDict objectForKey:serviceKey];
                
                // if SkipIfNotificationsDisabled, silently skip any services that don't have notifications enabled
                NSNumber *notificationsDisabled = [self.configData objectForKey:@"SkipIfNotificationsDisabled"];
                if ([notificationsDisabled intValue]) {
                    NSString *notificationsEnabled = [serviceDict valueForKey:@"notifications_enabled"];
                    if ([notificationsEnabled isEqualToString:@"0"]) {
                        continue;
                    }
                }
                
                NSString *stateNum = [serviceDict valueForKey:@"last_hard_state"];
                if (stateNum == nil) {
                    stateNum = [serviceDict valueForKey:@"current_state"];
                }
                [stateNum isEqual:@"0"] && okCount++;
                [stateNum isEqual:@"1"] && warnCount++;
                [stateNum isEqual:@"2"] && critCount++;
                [stateNum isEqual:@"3"] && unkCount++;
                totalCount++;
                
            }
            
        }
        
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[NSNumber numberWithInt:okCount] forKey:@"okCount"];
        [dict setObject:[NSNumber numberWithInt:warnCount] forKey:@"warnCount"];
        [dict setObject:[NSNumber numberWithInt:critCount] forKey:@"critCount"];
        [dict setObject:[NSNumber numberWithInt:unkCount] forKey:@"unkCount"];
        [dict setObject:[NSNumber numberWithInt:totalCount] forKey:@"totalCount"];
        [dict setObject:[server objectForKey:@"Name"] forKey:@"_name"];
        [dict setObject:server forKey:@"_server"];
        [results addObject:dict];
        
    }
    
    [self setCheckResults:results];
    
    [self performSelectorOnMainThread:@selector(doUIUpdate:) withObject:nil waitUntilDone:NO];
    
    inHere = NO; // exiting
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification{
    return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    
    // we don't need this - should disable it altogether, but for now we just hide it
    // at app start
    [self.window close];
    
    // status string starts off empty
    [self setLastStatusString:@""];
    
    
    NSStatusBar *bar = [NSStatusBar systemStatusBar];
    
    [self setStatusItem:[bar statusItemWithLength:NSVariableStatusItemLength]];
    
    /*
     NSStatusBar *bar = [NSStatusBar systemStatusBar];
     
     [self setStatusItem:[bar statusItemWithLength:NSVariableStatusItemLength]];
     
     [self.statusItem setTitle: NSLocalizedString(@" 32 OK, 1 Warning, 2 Critical",@"")];
     [self.statusItem setImage: [NSImage imageNamed:@"nagios-icon-smaller-red.png"]];
     [self.statusItem setHighlightMode:YES];
     
     NSMenu *menu = [[NSMenu alloc] initWithTitle:@"NagiosDock2"];
     [menu insertItemWithTitle:@"Test1" action:@selector(exampleHandler:) keyEquivalent:@"test1" atIndex:0];
     
     [menu insertItem:[NSMenuItem separatorItem] atIndex:1];
     
     [menu insertItemWithTitle:@"Quit" action:@selector(quitHandler:) keyEquivalent:@"quit" atIndex:2];
     
     [self.statusItem setMenu:menu];
     */
    
    
    /*
     [self setWebView:[[WebView alloc] initWithFrame:self.window.frame]];
     
     
     [self.window setContentView:self.webView];
     [self.webView setHostWindow:self.window];
     
     [self.webView setResourceLoadDelegate:self];
     */
    
    //[self.webView setMainFrameURL:@"http://localhost/test1"];
    
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    
    /*
     NSUserNotification *notification = [[NSUserNotification alloc] init];
     notification.title = @"Hello, World!";
     notification.informativeText = @"A notification";
     notification.soundName = NSUserNotificationDefaultSoundName;
     [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
     */
    
    NSString *bundlePath = [[NSBundle mainBundle] resourcePath];
    
    NSString *configPath = [bundlePath stringByAppendingPathComponent:@"macnagios-config.plist"];
    
    NSDictionary *config = [NSDictionary dictionaryWithContentsOfFile:configPath];
    
    if (config == nil) {
        NSLog(@"Cannot read from config.plist - it's either corrupt or it doesn't exist, trying to read from /etc/macnagios-config.plist.sample");
        // read from sample if main fails
        configPath = @"/etc/macnagios-config.plist";
        config = [NSDictionary dictionaryWithContentsOfFile:configPath];
        if (config == nil) {
            NSLog(@"Cannot read from /etc/macnagios-config.plist, either, nothing I can do about this - you fix it.");
            
            // we got issues, let the user know - so when the user first opens it, they have a hint of what to do
            
            NSAlert *alert = [[NSAlert alloc] init];
            //[alert setAlertStyle:NSRunInformationalAlertPanel];
            [alert addButtonWithTitle:@"OK"];
            [alert setMessageText:@"No nagios servers are configured!"];
            [alert setInformativeText:@"Find the folder for this app and look at the macnagios-config.json.sample file for instructions."];
            [alert setAlertStyle:NSWarningAlertStyle];
            if ([alert runModal] == NSAlertFirstButtonReturn) {
                //
            }
            
            return;
            
        }
    }
    
    NSLog(@"loaded config dictionary: %@", config);
    
    [self setConfigData:config];
    
    NSNumber *checkFrequencySeconds = [config valueForKey:@"CheckFrequencySeconds"];
    NSLog(@"checkFrequencySeconds: %@", checkFrequencySeconds);
    
    NSInteger checkFrequencySecondsInt = [checkFrequencySeconds integerValue];
    if (checkFrequencySecondsInt < 1) {
        NSLog(@"checkFrequencySeconds is too low, setting it to 30 seconds");
        checkFrequencySecondsInt = 30;
    }
    
    
    // kick off one in the background - the first time
    [NSTimer scheduledTimerWithTimeInterval:1
                                     target:self
                                   selector:@selector(timeoutHandler:)
                                   userInfo:nil
                                    repeats:NO];
    
    
    // subsequent times occur according to frequency
    [self setTimer:[NSTimer scheduledTimerWithTimeInterval:checkFrequencySecondsInt
                                                    target:self
                                                  selector:@selector(timeoutHandler:)
                                                  userInfo:nil
                                                   repeats:YES]];
    
    
    // do the initial update
    [self doUIUpdate:nil];
    
    //    NSLog(@"secondParentPath: %@", secondParentPath);
    
    // "growl" - have test code - DONE
    // PList parsing - DONE
    // JSON parsing - DONE
    // timed polling - DONE
    // menu item updating - DONE
    // opening right browser windows - DONE
    // changing icon color - DONE
    // play sound when critical or warning - make this an option - DONE
    // notifications_enabled == "0" then skip service - should be option - DONE
    // should have option to read config from /etc/macnagios-config.plist - DONE
    // clean up menu - DONE
    // make pop up happen at the right time - DONE
    // name - MacNagios? - DONE
    // implement UseColorIcons or get rid of the option (get rid of it) - DONE
    // see which service changed and include that in the notice
    // icon
    // github
    // binary packaging (google code?)
    
}

/*
 - (NSURLRequest *)webView:(WebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(WebDataSource *)dataSource
 {
 
 NSLog(@"host: %@", request.URL.host);
 
 if ([request.URL.host compare:@"localhost"] == 0) {
 NSLog(@"Yup, it's local");
 } else {
 }
 
 NSLog(@"HERE!");
 return request;
 
 }
 */


@end
