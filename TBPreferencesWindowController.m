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
#import "AKSummaryView.h"
#import "TBSummaryGenerator.h"

#define SUMMARY_PANE	@"Summary"
#define GENERAL_PANE	@"General"
#define MONITORING_PANE	@"Monitoring"
#define ADVACNED_PANE	@"Advanced"


@interface TBPreferencesWindowController ()

- (void)_selectPane:(NSString *)pane;

@end


@implementation TBPreferencesWindowController


- (id)init {
	self = [super initWithWindowNibName:@"TBPreferencesWindow"];
	if (!self) return nil;
	
	return self;
}
- (void)awakeFromNib {
	
	// summary generator
	if (!_summaryGenerator)
	{
		_summaryGenerator = [[TBSummaryGenerator alloc] init];
		// bindings & notifications
		NSArray *bindings = [NSArray arrayWithObjects:
							 Property(rollingPeriodFactor),
							 Property(rollingPeriodMultiplier),
							 Property(fixedPeriodInterval),
							 Property(shouldNotify),
							 Property(criticalPercentage),
							 Property(limit),
							 Property(monitoringMode),
							 Property(monitoring), nil];
		for (NSString *bindingKey in bindings)
			[_summaryGenerator bind:bindingKey 
						   toObject:[NSUserDefaultsController sharedUserDefaultsController] 
						withKeyPath:[@"values." stringByAppendingString:bindingKey]
							options:nil];
	}
	
	// summary view
	NSShadow *vShadow = [[[NSShadow alloc] init] autorelease];
	[vShadow setShadowColor:[NSColor blackColor]];
	[vShadow setShadowBlurRadius:3];
	[vShadow setShadowOffset:NSMakeSize(0, -1)];
	[summaryView setShadow:vShadow];
	[summaryView setBackgroundImage:[NSImage imageNamed:@"GraphWindowBackground.png"]];
	[summaryView setTextColor:[NSColor whiteColor]];
	[summaryView bind:Property(summaryString)
			 toObject:_summaryGenerator
		  withKeyPath:Property(summaryString)
			  options:nil];
	
	// window sizing
	[self.window setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
	NSRect frame = generalView.frame;
	frame.size.height = 75; // offset for the toolbar
    [self.window setFrame:frame display:NO animate:NO];
	[self.window center];	
}
- (void)windowDidLoad {
	[self _selectPane:SUMMARY_PANE];
}


#pragma mark -
#pragma mark IBAction methods

- (IBAction)continueToSetup:(id)sender {
	[self _selectPane:MONITORING_PANE];
}

- (IBAction)didSelectToolbarItem:(id)sender {
	
	NSView *oldPreferencesView = _preferencesView;
	
	NSString *identifier = [pToolbar selectedItemIdentifier];
	if ([identifier isEqual:SUMMARY_PANE])
		_preferencesView = statusView;
	else if ([identifier isEqual:GENERAL_PANE])
		_preferencesView = generalView;
	else if ([identifier isEqual:MONITORING_PANE])
		_preferencesView = monitoringView;
	else if ([identifier isEqual:ADVACNED_PANE])
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


#pragma mark -
#pragma mark private
- (void)_selectPane:(NSString *)pane {
	[pToolbar setSelectedItemIdentifier:pane];
	[self didSelectToolbarItem:pane];
}

@end
