//
//  TBStatusViewController.m
//  TrafficBot
//
//  Created by Adam Ko on 25/10/2010.
//  Copyright 2010 Loca Apps. All rights reserved.
//

#import "TBStatusWindowController.h"
#import "AKTrafficMonitorService.h"
#import "TrafficBotAppDelegate.h"
#import "MAAttachedWindow.h"
#import "NSWindow+NoodleEffects.h"
#import "NSWindow+AKFlip.h"
#import "AKGaugeView.h"
#import "TBGraphView.h"
#import "TBSetupView.h"
#import "AKBytesFormatter.h"

@interface TBStatusWindowController (Private)
- (void)_refreshStatusView;
- (void)_didReceiveNotificationFromTrafficMonitorService:(NSNotification *)notification;
- (void)_setUsageWithTotalIn:(NSNumber *)totalIn totalOut:(NSNumber *)totalOut;
@end

#pragma mark -
@implementation TBStatusWindowController
- (id)initWithWindowNibName:(NSString *)windowNibName {
	self = [super initWithWindowNibName:windowNibName];
	if (!self) return nil;
	_monitoring = NO;
	_limit = nil;
	return self;
}
- (void)dealloc {
    [usageTextField release], usageTextField = nil;
	[super dealloc];
}
#pragma mark -
#pragma mark nib loading
- (void)awakeFromNib {
	// not monitoring view
	if (!_notMonitoringView)
		_notMonitoringView = [[TBSetupView alloc] initWithFrame:self.contentView.bounds];
	_notMonitoringView.infoString = NSLocalizedString(@"TrafficBot is not monitoring.", @"not monitoring");
	[self.contentView addSubview:_notMonitoringView];
	// bindings & notifications
	NSArray *bindings = [NSArray arrayWithObjects:
						 @"monitoring", Property(limit), nil];
	for (NSString *bindingKey in bindings)
		[self bind:bindingKey 
		  toObject:[NSUserDefaultsController sharedUserDefaultsController] 
	   withKeyPath:[@"values." stringByAppendingString:bindingKey]
		   options:nil];
	[[AKTrafficMonitorService sharedService] addObserver:self selector:@selector(_didReceiveNotificationFromTrafficMonitorService:)];
	[self.gaugeView bind:@"criticalPercentage" 
				toObject:[NSUserDefaultsController sharedUserDefaultsController]
			 withKeyPath:@"values.criticalPercentage" 
				 options:nil];
}
#pragma mark -
#pragma mark setters & getters
- (void)setMonitoring:(BOOL)inBool {
	_monitoring = inBool;
	[_notMonitoringView removeFromSuperview];
	if (_monitoring) return;
	[self.contentView addSubview:_notMonitoringView];
}
- (void)setLimit:(NSNumber *)newLimit {
	if ([_limit isEqualToNumber:newLimit]) return;
	[_limit release];
	_limit = [newLimit retain];
	[self _refreshStatusView];
}
#pragma mark -
#pragma mark ui methods
- (void)show:(id)sender {
	// shows status view
	if ([[self.window class] isNotEqualTo:[MAAttachedWindow class]]) {
		MAAttachedWindow *window = [[[MAAttachedWindow alloc] initWithView:self.contentView 
														   attachedToPoint:NSZeroPoint
																  inWindow:nil 
																	onSide:MAPositionBottom 
																atDistance:3.0f] autorelease];
		[window setArrowHeight:10];
		[window setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
		self.window = window;
		// force window on screen to avoid glitch
		[window setAlphaValue:0];
		[window orderFront:sender];
		[window orderOut:sender];
		[window setAlphaValue:1];
	}
	[(MAAttachedWindow *)self.window setPoint:[[NSApp delegate] statusItemPoint]];
	[self.window zoomOnFromRect:[[NSApp delegate] statusItemFrame]];
	[self _refreshStatusView];
}
- (void)dismiss:(id)sender {
	[self.window zoomOffToRect:[[NSApp delegate] statusItemFrame]];
	[gaugeView setPercentage:0 animated:NO];
}
- (IBAction)info:(id)sender {
	[[NSApp delegate] showGraphWindow:sender];
}
- (IBAction)preferences:(id)sender {
	[[NSApp delegate] showPreferencesWindow:self];
}
@synthesize contentView, gaugeView, usageTextField;
@synthesize monitoring = _monitoring, limit = _limit;
@end
#pragma mark -
@implementation TBStatusWindowController (Private)
#pragma mark -
#pragma mark status view
- (void)_refreshStatusView {
	
	BOOL animated = [self.window isVisible];
	
	// update display
	NSNumber *totalIn = [[AKTrafficMonitorService sharedService] totalIn];
	NSNumber *totalOut = [[AKTrafficMonitorService sharedService] totalOut];
	[self _setUsageWithTotalIn:totalIn totalOut:totalOut];
	if ([self.limit intValue] == 0) {
		[gaugeView setPercentage:0 animated:NO];
	}
	else {
		TMS_ULL_T ullTotal = ULLFromNumber(totalIn) + ULLFromNumber(totalOut);
		float percentage = (float)ullTotal / [self.limit floatValue] * 100;
		if (percentage > 100) {
			[gaugeView setPercentage:100 animated:animated];
			return;
		}
		[gaugeView setPercentage:percentage animated:animated];
	}
}
- (void)_setUsageWithTotalIn:(NSNumber *)totalIn totalOut:(NSNumber *)totalOut {
	TMS_ULL_T ullTotal = [totalIn unsignedLongLongValue] + [totalOut unsignedLongLongValue];
	NSNumber *total = [NSNumber numberWithUnsignedLongLong:ullTotal];
	[usageTextField setTitleWithMnemonic:
	 [NSString stringWithFormat:@"In: %@\nOut: %@\nTotal: %@",
	  [AKBytesFormatter convertBytesWithNumber:totalIn decimals:NO],
	  [AKBytesFormatter convertBytesWithNumber:totalOut decimals:NO],
	  [AKBytesFormatter convertBytesWithNumber:total decimals:NO]]];
}
#pragma mark monitor service notifications
- (void)_didReceiveNotificationFromTrafficMonitorService:(NSNotification *)notification {
	if ([[notification name] isEqual:AKTrafficMonitorStatisticsDidUpdateNotification]) {
		// stats did update
		[self _refreshStatusView];
	}
}
@end
