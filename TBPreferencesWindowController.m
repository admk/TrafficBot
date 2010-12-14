//
//  TBPreferencesWindowController.m
//  TrafficBot
//
//  Created by Adam Ko on 31/10/2010.
//  Copyright 2010 Loca Apps. All rights reserved.
//

#import "TBPreferencesWindowController.h"
#import "AKTrafficMonitorService.h"

@implementation TBPreferencesWindowController

- (id)init {
	self = [super initWithWindowNibName:@"TBPreferencesWindow"];
	if (!self) return nil;
	
	return self;
}
- (void)awakeFromNib {
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
	
	float heightDelta = _preferencesView.frame.size.height - oldPreferencesView.frame.size.height;
    NSRect frame = [self.window frame];
    frame.origin.y -= heightDelta;
    frame.size.height += heightDelta;
	
    [self.window setFrame:frame display:YES animate:YES];
	[self.window.contentView addSubview:_preferencesView];
}

- (IBAction)clearStatistics:(id)sender {
	[[AKTrafficMonitorService sharedService] clearStatistics];
}

- (IBAction)resetAllPrefs:(id)sender{
	[[NSUserDefaults standardUserDefaults] removePersistentDomainForName:[[NSBundle mainBundle] bundleIdentifier]];
}

#pragma mark defaults update

- (IBAction)updateRollingPeriodTimeInterval:(id)sender {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	float factor = [[defaults valueForKey:@"rollingPeriodFactor"] floatValue];
	float multiplier = [[defaults valueForKey:@"rollingPeriodMultiplier"] floatValue];
	NSNumber *interval = NumberFromULL(factor * multiplier);
	[[NSUserDefaults standardUserDefaults] setValue:interval forKey:@"rollingPeriodInterval"];
}

- (IBAction)updateLimit:(id)sender {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	TMS_ULL_T factor = [[defaults valueForKey:@"limitFactor"] floatValue];
	TMS_ULL_T multiplier = [[defaults valueForKey:@"limitMultiplier"] floatValue];
	NSNumber *limit = NumberFromULL(factor * multiplier);
	[[NSUserDefaults standardUserDefaults] setValue:limit forKey:@"limit"];
}

@end
