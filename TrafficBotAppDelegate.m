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

#define TMS_B_STRING		Property(rollingPeriodInterval), \
							Property(fixedPeriodRestartDate), \
							Property(monitoringMode), \
							@"monitoring",
#define TMS_BINDINGS		([NSArray arrayWithObjects: TMS_B_STRING	nil	])

@interface TrafficBotAppDelegate (Private)
- (void)_newRestartDate;
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
#ifndef DEBUG
	BOOL firstLaunch = [[NSUserDefaults standardUserDefaults] boolForKey:@"firstLaunch"];
#else
	BOOL firstLaunch = YES;
#endif
	if (firstLaunch) {
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"firstLaunch"];
		[self showFirstLaunchWindow:self];
		[NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(dismissFirstLaunchWindow:) userInfo:nil repeats:NO];
	}
	
	// bindings & notifications
	for (NSString *bindingKey in TMS_BINDINGS)
		[[AKTrafficMonitorService sharedService] bind:bindingKey 
		  toObject:[NSUserDefaultsController sharedUserDefaultsController] 
	   withKeyPath:[@"values." stringByAppendingString:bindingKey]
		   options:nil];
	[[AKTrafficMonitorService sharedService] addObserver:self selector:@selector(_didReceiveNotificationFromTrafficMonitorService:)];
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
	return (NSPoint){ NSMidX(frame), NSMinY(frame) };
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
@end

#pragma mark -
@implementation TrafficBotAppDelegate (Private)
#pragma mark AKTrafficMonitorService
- (void)_newRestartDate {
	NSDate *restartDate = [NSDate date];
	NSNumber *interval = [[NSUserDefaults standardUserDefaults] objectForKey:@"fixedPeriodInterval"];
	long fixedPeriodInterval = [interval longValue];
	switch (fixedPeriodInterval) {
		case 3600:
			restartDate = [restartDate nextHour];
			break;
		case 86400:
			restartDate = [restartDate midnightTomorrow];
			break;
		case 2592000:
			restartDate = [restartDate midnightNextMonth];
			break;
		default:
			ALog(@"invalid fixedPeriodInterval: %l", fixedPeriodInterval);
			break;
	}
	DLog(@"new restart date: %@", [restartDate description]);
	[[NSUserDefaults standardUserDefaults] setValue:restartDate forKey:Property(fixedPeriodRestartDate)];
}
#pragma mark monitor service notifications
- (void)_didReceiveNotificationFromTrafficMonitorService:(NSNotification *)notification {
	if ([[notification name] isEqual:AKTrafficMonitorNeedsNewFixedPeriodRestartDateNotification]) {
		DLog(@"received: %@", notification);
		// update restart date
		[self _newRestartDate];
	}
}

@end
