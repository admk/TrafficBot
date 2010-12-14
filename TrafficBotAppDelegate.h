//
//  TrafficBotAppDelegate.h
//  TrafficBot
//
//  Created by Adam Ko on 25/10/2010.
//  Copyright 2010 Loca Apps. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TBPreferencesWindowController;
@class TBStatusViewController, TBGraphWindowController;
@class TBStatusItemController;

@interface TrafficBotAppDelegate : NSObject <NSApplicationDelegate> {
	
	// ui
	IBOutlet TBStatusItemController	*statusItemController;
	TBStatusViewController			*statusViewController;
	TBGraphWindowController			*graphWindowController;
	TBPreferencesWindowController	*preferencesWindowController;
	
}

- (void)showPreferencesWindow:(id)sender;
- (void)showStatusView:(id)sender atPoint:(NSPoint)point;
- (void)dismissStatusView:(id)sender;
- (void)showGraphWindow:(id)sender atPoint:(NSPoint)point;
- (void)dismissGraphWindow:(id)sender;

@end
