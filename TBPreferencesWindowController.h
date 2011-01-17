//
//  TBPreferencesWindowController.h
//  TrafficBot
//
//  Created by Adam Ko on 31/10/2010.
//  Copyright 2010 Loca Apps. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface TBPreferencesWindowController : NSWindowController {
	
	IBOutlet NSToolbar *pToolbar;
	IBOutlet NSView *statusView;
	IBOutlet NSView *generalView;
	IBOutlet NSView *advancedView;
	
@private
	__weak NSView *_preferencesView;
}

// IBAction methods
- (IBAction)didSelectToolbarItem:(id)sender;
- (IBAction)clearStatistics:(id)sender;
- (IBAction)resetAllPrefs:(id)sender;

- (IBAction)updateRollingPeriodTimeInterval:(id)sender;
- (IBAction)updateLimit:(id)sender;
- (IBAction)updateThresholds:(id)sender;

@end
