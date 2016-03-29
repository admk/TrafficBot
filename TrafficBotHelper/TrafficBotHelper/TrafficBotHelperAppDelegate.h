//
//  TrafficBotHelperAppDelegate.h
//  TrafficBotHelper
//
//  Created by Xitong Gao on 24/09/2011.
//  Copyright 2011 AK.Kloca. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TrafficBotHelperAppDelegate
    : NSObject<NSApplicationDelegate, NSWindowDelegate>
{
    AuthorizationRef _auth;

    IBOutlet NSTextField *_linkTextField;
    NSWindow *_window;
}

@property (assign) IBOutlet NSWindow *window;

- (IBAction)install:(id)sender;
- (IBAction)uninstall:(id)sender;

@end
