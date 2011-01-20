//
//  TrafficBotAppDelegate.m
//  TrafficBot
//
//  Created by Adam Ko on 25/10/2010.
//  Copyright 2010 Loca Apps. All rights reserved.
//

#import "TrafficBotAppDelegate.h"
#import "AKTrafficMonitorService.h"
#import "TBPreferencesWindowController.h"
#import "TBFirstLaunchWindowController.h"
#import "TBStatusWindowController.h"
#import "TBGraphWindowController.h"
#import "TBStatusItemController.h"
#import "NSDate+AKMidnight.h"


@interface TrafficBotAppDelegate (Private)
- (void)_newRestartDate;
- (void)_sendGrowlNotificationWithTitle:(NSString *)title description:(NSString *)description notificationName:(NSString *)name;
- (void)_didReceiveNotificationFromTrafficMonitorService:(NSNotification *)notification;
@end

@implementation TrafficBotAppDelegate

#pragma mark -
#pragma mark init
- (void)awakeFromNib {
	[statusItemController showStatusItem];
}

#pragma mark app delegate notification methods
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	
	// setup defaults
	NSString *defaultsPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"TBDefaults.plist"];
	NSDictionary *defaultsDict = [NSDictionary dictionaryWithContentsOfFile:defaultsPath];
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
	
	// first launch
	BOOL firstLaunch = [[NSUserDefaults standardUserDefaults] boolForKey:@"firstLaunch"];
	if (firstLaunch) {
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"firstLaunch"];
		[self showFirstLaunchWindow:self];
		[NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(dismissFirstLaunchWindow:) userInfo:nil repeats:NO];
	}
	
	// bindings & notifications
	NSArray *bindings = [NSArray arrayWithObjects:
						 Property(rollingPeriodInterval),
						 Property(fixedPeriodRestartDate),
						 Property(monitoringMode),
						 @"monitoring", nil];
	for (NSString *bindingKey in bindings)
		[[AKTrafficMonitorService sharedService] bind:bindingKey 
		  toObject:[NSUserDefaultsController sharedUserDefaultsController] 
	   withKeyPath:[@"values." stringByAppendingString:bindingKey]
		   options:nil];
	[[AKTrafficMonitorService sharedService] addObserver:self selector:@selector(_didReceiveNotificationFromTrafficMonitorService:)];
	
	// threshold notifications
	[self refreshThresholds];
	[GrowlApplicationBridge setGrowlDelegate:self];
}
- (void)applicationDidResignActive:(NSNotification *)notification {
#ifndef DEBUG
	[self dismissStatusView:self];
	[self dismissGraphWindow:self];
#endif
}
- (void)applicationWillTerminate:(NSNotification *)notification {
	[[AKTrafficMonitorService sharedService] removeObserver:self];
}

#pragma mark -
#pragma mark ui methods
- (NSRect)statusItemFrame {
	return statusItemController.statusItemView.window.frame;
}
- (NSPoint)statusItemPoint {
	NSRect frame = [self statusItemFrame];
	NSPoint fPoint = { NSMidX(frame), NSMinY(frame) };
	fPoint.x = round(fPoint.x);
	fPoint.y = round(fPoint.y);
	return fPoint;
}
- (void)showPreferencesWindow:(id)sender {
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
	if (!preferencesWindowController)
		preferencesWindowController = [[TBPreferencesWindowController alloc] init];
	[preferencesWindowController showWindow:nil];
	[self dismissStatusWindow:sender];
	[self dismissFirstLaunchWindow:sender];
	[graphWindowController dismiss:sender];
}
- (void)showFirstLaunchWindow:(id)sender {
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
	if (!firstLaunchWindowController)
		firstLaunchWindowController = [[TBFirstLaunchWindowController alloc] initWithWindowNibName:@"TBFirstLaunchWindow"];
	[firstLaunchWindowController show:sender];
}
- (void)dismissFirstLaunchWindow:(id)sender {
	[firstLaunchWindowController dismiss:sender];
}
- (void)showStatusWindow:(id)sender {
	[self dismissFirstLaunchWindow:sender];
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
	if (!statusWindowController)
		statusWindowController = [[TBStatusWindowController alloc] initWithWindowNibName:@"TBStatusWindow"];
	[statusWindowController show:sender];
}
- (void)dismissStatusWindow:(id)sender {
	[statusWindowController dismiss:sender];
	[statusItemController dismissHighlight:sender];
}
- (void)showGraphWindow:(id)sender {
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
	if (!graphWindowController)
		graphWindowController = [[TBGraphWindowController alloc] initWithWindowNibName:@"TBGraphWindow"];
	[graphWindowController flip:sender fromWindow:statusWindowController.window];
}
- (void)dismissGraphWindow:(id)sender {
	[graphWindowController dismiss:sender];
	[statusItemController dismissHighlight:sender];
}

#pragma mark -
#pragma mark thresholds
#define LIMIT_REMINDER @"Limit Reminder"
#define LIMIT_EXCEEDED @"Limit Exceeded"
- (void)refreshThresholds {
	float criticalPercentage = [Defaults(criticalPercentage) floatValue];
	float limit = [Defaults(limit) floatValue];
	NSNumber *threshold = [NSNumber numberWithFloat:(criticalPercentage * limit / 100.0f)];
	[[AKTrafficMonitorService sharedService] unregisterAllThresholds];
	[[AKTrafficMonitorService sharedService] registerThresholdWithValue:threshold context:LIMIT_REMINDER];
	[[AKTrafficMonitorService sharedService] registerThresholdWithValue:Defaults(limit) context:LIMIT_EXCEEDED];
}

@end

#pragma mark -
@implementation TrafficBotAppDelegate (Private)
#pragma mark AKTrafficMonitorService
- (void)_newRestartDate {
	NSDate *restartDate = [NSDate date];
	long fixedPeriodInterval = [Defaults(fixedPeriodInterval) longValue];
	switch (fixedPeriodInterval) {
		case 3600:		restartDate = [restartDate nextHour];			break;
		case 86400:		restartDate = [restartDate midnightTomorrow];	break;
		case 2592000:	restartDate = [restartDate midnightNextMonth];	break;
		default: ALog(@"invalid fixedPeriodInterval: %l", fixedPeriodInterval); break;
	}
	DLog(@"new restart date: %@", [restartDate description]);
	SetDefaults(restartDate, fixedPeriodRestartDate);
}

#pragma mark -
#pragma mark growl
- (NSDictionary *)registrationDictionaryForGrowl {
	NSArray* notifications = [NSArray arrayWithObjects:LIMIT_REMINDER, LIMIT_EXCEEDED, nil];
	return [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInt:1], GROWL_TICKET_VERSION,
			notifications, GROWL_NOTIFICATIONS_DEFAULT,
			notifications, GROWL_NOTIFICATIONS_ALL, nil];
}
- (NSString *)applicationNameForGrowl {
	return @"TrafficBot";
}
- (void)growlNotificationWasClicked:(id)clickContext {
	
}
- (void)_sendGrowlNotificationWithTitle:(NSString *)title description:(NSString *)description notificationName:(NSString *)name {
	[GrowlApplicationBridge notifyWithTitle:title
								description:description
						   notificationName:name
								   iconData:nil
								   priority:0
								   isSticky:NO
							   clickContext:name];
}

#pragma mark -
#pragma mark monitor service notifications
- (void)_didReceiveNotificationFromTrafficMonitorService:(NSNotification *)notification {
	if ([[notification name] isEqual:AKTrafficMonitorNeedsNewFixedPeriodRestartDateNotification]) {
		DLog(@"received: %@", notification);
		// update restart date
		[self _newRestartDate];
	}
	if ([[notification name] isEqual:AKTrafficMonitorThresholdDidExceedNotification]) {
		DLog(@"received: %@", notification);
		NSDictionary *infoDict = [notification userInfo];
		NSString *context = [[infoDict allKeys] objectAtIndex:0];
		if ([context isEqual:LIMIT_REMINDER]) {
			float criticalPercentage = [Defaults(criticalPercentage) floatValue];
			NSString *title = [NSString stringWithFormat:@"You have used %.0f%% of your limit.", criticalPercentage];
			[self _sendGrowlNotificationWithTitle:title description:nil notificationName:LIMIT_REMINDER];
		}
		else if ([context isEqual:LIMIT_EXCEEDED]) {
			NSString *title = [NSString stringWithFormat:@"You have used all of your limit."];
			[self _sendGrowlNotificationWithTitle:title description:nil notificationName:LIMIT_EXCEEDED];
		}
	}	
}

@end
