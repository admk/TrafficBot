//
//  TrafficBotAppDelegate.h
//  TrafficBot
//
//  Created by Adam Ko on 25/10/2010.
//  Copyright 2010 Loca Apps. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Growl/Growl.h>

@class TBPreferencesWindowController;
@class TBFirstLaunchWindowController;
@class TBStatusWindowController, TBGraphWindowController;
@class TBStatusItemController;

@interface TrafficBotAppDelegate : NSObject <NSApplicationDelegate, GrowlApplicationBridgeDelegate> {
	
	// ui
	IBOutlet TBStatusItemController	*statusItemController;
	TBFirstLaunchWindowController	*firstLaunchWindowController;
	TBStatusWindowController			*statusWindowController;
	TBGraphWindowController			*graphWindowController;
	TBPreferencesWindowController	*preferencesWindowController;
	
}

- (NSRect)statusItemFrame;
- (NSPoint)statusItemPoint;

- (void)showPreferencesWindow:(id)sender;
- (void)showFirstLaunchWindow:(id)sender;
- (void)dismissFirstLaunchWindow:(id)sender;
- (void)showStatusWindow:(id)sender;
- (void)dismissStatusWindow:(id)sender;
- (void)showGraphWindow:(id)sender;
- (void)dismissGraphWindow:(id)sender;

@end
