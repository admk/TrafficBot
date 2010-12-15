//
//  TrafficBotAppDelegate.h
//  TrafficBot
//
//  Created by Adam Ko on 25/10/2010.
//  Copyright 2010 Loca Apps. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TBPreferencesWindowController;
@class TBStatusWindowController, TBGraphWindowController;
@class TBStatusItemController;

@interface TrafficBotAppDelegate : NSObject <NSApplicationDelegate> {
	
	// ui
	IBOutlet TBStatusItemController	*statusItemController;
	TBStatusWindowController		*statusWindowController;
	TBGraphWindowController			*graphWindowController;
	TBPreferencesWindowController	*preferencesWindowController;
	
}

- (void)showPreferencesWindow:(id)sender;
- (void)showStatusWindow:(id)sender atPoint:(NSPoint)point;
- (void)dismissStatusWindow:(id)sender;
- (void)showGraphWindow:(id)sender atPoint:(NSPoint)point;
- (void)dismissGraphWindow:(id)sender;

@end
