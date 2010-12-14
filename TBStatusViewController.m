//
//  TBStatusViewController.m
//  TrafficBot
//
//  Created by Adam Ko on 25/10/2010.
//  Copyright 2010 Loca Apps. All rights reserved.
//

#import "TBStatusViewController.h"
#import "AKTrafficMonitorService.h"
#import "TrafficBotAppDelegate.h"
#import "MAAttachedWindow.h"
#import "NSWindow+NoodleEffects.h"
#import "NSWindow+AKFlip.h"
#import "AKGaugeView.h"
#import "TBGraphView.h"
#import "AKBytesFormatter.h"

@interface TBStatusViewController (Private)
- (void)_refreshStatusView;
- (void)_didReceiveNotificationFromTrafficMonitorService:(NSNotification *)notification;
- (void)_setUsageWithTotalIn:(NSNumber *)totalIn totalOut:(NSNumber *)totalOut;
@end

#pragma mark -
@implementation TBStatusViewController
- (void)dealloc {
    [usageTextField release], usageTextField = nil;
	[super dealloc];
}
- (void)awakeFromNib {
	
	[self setMonitoring:NO];
	
	// bindings & notifications
	NSArray *bindings = [NSArray arrayWithObjects:
						 @"monitoring", Property(limit), nil];
	for (NSString *bindingKey in bindings)
		[self bind:bindingKey 
		  toObject:[NSUserDefaultsController sharedUserDefaultsController] 
	   withKeyPath:[@"values." stringByAppendingString:bindingKey]
		   options:nil];
	[[AKTrafficMonitorService sharedService] addObserver:self selector:@selector(_didReceiveNotificationFromTrafficMonitorService:)];
	[gaugeView bind:@"criticalPercentage" 
		   toObject:[NSUserDefaultsController sharedUserDefaultsController]
		withKeyPath:@"values.criticalPercentage" 
			options:nil];
}
#pragma mark -
#pragma mark setters & getters
- (void)setMonitoring:(BOOL)inBool {
	_monitoring = inBool;
	[notMonitoringView removeFromSuperview];
	if (_monitoring) return;
	[self.view addSubview:notMonitoringView];
}
- (void)setLimit:(NSNumber *)newLimit {
	if ([_limit isEqualToNumber:newLimit]) return;
	[_limit release];
	_limit = [newLimit retain];
	[self _refreshStatusView];
}
#pragma mark -
#pragma mark ui methods
- (void)show:(id)sender atPoint:(NSPoint)point {
	
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
	
	// shows status view
	_statusItemRect = [sender convertRect:[sender bounds] toView:nil];
	_statusItemRect.origin = point;
	if (!window) {
		window = [[MAAttachedWindow alloc] initWithView:self.view 
										attachedToPoint:_statusItemRect.origin 
											   inWindow:nil 
												 onSide:MAPositionBottom 
											 atDistance:3.0];
		[window setArrowHeight:10];
		[window setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
		[window makeKeyAndOrderFront:self];
	}
	else {
		[window setPoint:point];
		[window zoomOnFromRect:_statusItemRect];
	}
	[self _refreshStatusView];
}
- (void)dismiss:(id)sender {
	[window zoomOffToRect:_statusItemRect];
	[gaugeView setPercentage:0 animated:NO];
}
- (IBAction)info:(id)sender {
	[[NSApp delegate] showGraphWindow:sender atPoint:_statusItemRect.origin];
}
- (IBAction)preferences:(id)sender {
	[[NSApp delegate] showPreferencesWindow:self];
}
@synthesize window;
@synthesize monitoring = _monitoring, limit = _limit;
@end
#pragma mark -
@implementation TBStatusViewController (Private)
#pragma mark -
#pragma mark status view
- (void)_refreshStatusView {
	
	BOOL animated = [window isVisible];
	
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
	  [AKBytesFormatter convertBytesWithNumber:totalIn],
	  [AKBytesFormatter convertBytesWithNumber:totalOut],
	  [AKBytesFormatter convertBytesWithNumber:total]]];
}
#pragma mark monitor service notifications
- (void)_didReceiveNotificationFromTrafficMonitorService:(NSNotification *)notification {
	if ([[notification name] isEqual:AKTrafficMonitorStatisticsDidUpdateNotification]) {
		// stats did update
		[self _refreshStatusView];
	}
}@end