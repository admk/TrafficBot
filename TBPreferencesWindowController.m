//
//  TBPreferencesWindowController.m
//  TrafficBot
//
//  Created by Adam Ko on 31/10/2010.
//  Copyright 2010 Loca Apps. All rights reserved.
//

#import "TBPreferencesWindowController.h"
#import "AKTrafficMonitorService.h"
#import "TrafficBotAppDelegate.h"

@implementation TBPreferencesWindowController

- (id)init {
	self = [super initWithWindowNibName:@"TBPreferencesWindow"];
	if (!self) return nil;
	
	return self;
}
- (void)awakeFromNib {
	[self.window setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
	// window sizing
	NSRect frame = generalView.frame;
	frame.size.height = 75; // offset for the toolbar
    [self.window setFrame:frame display:NO animate:NO];
	[self.window center];	
}
- (void)windowDidLoad {
	[pToolbar setSelectedItemIdentifier:@"Status"];
	[self didSelectToolbarItem:@"Status"];
}

#pragma mark -
#pragma mark IBAction methods

- (IBAction)didSelectToolbarItem:(id)sender {
	
	NSView *oldPreferencesView = _preferencesView;
	
	NSString *identifier = [pToolbar selectedItemIdentifier];
	if ([identifier isEqual:@"Status"])
		_preferencesView = statusView;
	else if ([identifier isEqual:@"General"])
		_preferencesView = generalView;
	else if ([identifier isEqual:@"Advanced"])
		_preferencesView = advancedView;
	
	if (oldPreferencesView == _preferencesView) return;
	
	[oldPreferencesView removeFromSuperview];
	
	float heightDelta = (float)(_preferencesView.frame.size.height - oldPreferencesView.frame.size.height);
    NSRect frame = [self.window frame];
    frame.origin.y -= heightDelta;
    frame.size.height += heightDelta;
	
    [self.window setFrame:frame display:YES animate:YES];
	[self.window.contentView addSubview:_preferencesView];
}

- (IBAction)clearStatistics:(id)sender {
	[[AKTrafficMonitorService sharedService] clearStatistics];
	[self updateThresholds:sender];
}

- (IBAction)resetAllPrefs:(id)sender{
	[[NSUserDefaults standardUserDefaults] removePersistentDomainForName:[[NSBundle mainBundle] bundleIdentifier]];
}

#pragma mark defaults update

- (IBAction)updateRollingPeriodTimeInterval:(id)sender {
	float factor = [Defaults(rollingPeriodFactor) floatValue];
	float multiplier = [Defaults(rollingPeriodMultiplier) floatValue];
	NSNumber *interval = [NSNumber numberWithFloat:(factor * multiplier)];
	SetDefaults(interval, rollingPeriodInterval);
}

- (IBAction)updateLimit:(id)sender {
	float factor = [Defaults(limitFactor) floatValue];
	float multiplier = [Defaults(limitMultiplier) floatValue];
	NSNumber *limit = [NSNumber numberWithFloat:(factor * multiplier)];
	SetDefaults(limit, limit);
	// limit affects threshold too
	[self updateThresholds:sender];
}

- (IBAction)updateThresholds:(id)sender {
	[[NSApp delegate] refreshThresholds];
}

@end
