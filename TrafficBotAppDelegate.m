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
#import "TBStatusViewController.h"
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
	
	for (NSString *bindingKey in TMS_BINDINGS)
		[[AKTrafficMonitorService sharedService] bind:bindingKey 
		  toObject:[NSUserDefaultsController sharedUserDefaultsController] 
	   withKeyPath:[@"values." stringByAppendingString:bindingKey]
		   options:nil];
	
	[[AKTrafficMonitorService sharedService] addObserver:self selector:@selector(_didReceiveNotificationFromTrafficMonitorService:)];
}
- (void)applicationDidResignActive:(NSNotification *)notification {
	/*
	[self dismissStatusView:self];
	[self dismissGraphWindow:self];
	//*/
}
- (void)applicationWillTerminate:(NSNotification *)notification {
	[[AKTrafficMonitorService sharedService] removeObserver:self];
}

#pragma mark -
#pragma mark ui methods
- (void)showPreferencesWindow:(id)sender {
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
	if (!preferencesWindowController)
		preferencesWindowController = [[TBPreferencesWindowController alloc] init];
	[preferencesWindowController showWindow:nil];
	[self dismissStatusView:sender];
	[graphWindowController dismiss:sender];
}
- (void)showStatusView:(id)sender atPoint:(NSPoint)point {
	if (!statusViewController)
		statusViewController = [[TBStatusViewController alloc] initWithNibName:@"TBStatusView" bundle:nil];
	[statusViewController show:sender atPoint:point];
}
- (void)dismissStatusView:(id)sender {
	[statusViewController dismiss:sender];
	[statusItemController dismissHighlight:sender];
}
- (void)showGraphWindow:(id)sender atPoint:(NSPoint)point {
	if (!graphWindowController)
		graphWindowController = [[TBGraphWindowController alloc] initWithWindowNibName:@"TBGraphWindow"];
	[graphWindowController flip:sender fromWindow:(NSWindow *)statusViewController.window atPoint:point];
}
- (void)dismissGraphWindow:(id)sender {
	[graphWindowController dismiss:sender];
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
