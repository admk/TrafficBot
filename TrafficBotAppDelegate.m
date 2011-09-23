//
//  TrafficBotAppDelegate.m
//  TrafficBot
//
//  Created by Adam Ko on 25/10/2010.
//  Copyright 2010 Loca Apps. All rights reserved.
//

#import "TrafficBotAppDelegate.h"
#import "AKTrafficMonitorService.h"
#import "AKLandmarkManager.h"
#import "TBPreferencesWindowController.h"
#import "TBFirstLaunchWindowController.h"
#import "TBStatusWindowController.h"
#import "TBGraphWindowController.h"
#import "TBStatusItemController.h"
#import "NSDate+AKMidnight.h"


#define LIMIT_REMINDER @"Limit Reminder"
#define LIMIT_EXCEEDED @"Limit Exceeded"
#define LOCATION_CHANGED @"Location Changed"
#define ERROR_MESSAGE  @"Errors"

@interface TrafficBotAppDelegate (Private)

- (void)_simulateCrash;

- (void)_newRestartDate;

- (void)_sendGrowlNotificationWithTitle:(NSString *)title description:(NSString *)description notificationName:(NSString *)name;

- (void)_didReceiveNotificationFromTrafficMonitorService:(NSNotification *)notification;
- (void)_didReceiveNotificationFromLocationManager:(NSNotification *)notification;

@end

@implementation TrafficBotAppDelegate

#pragma mark -
#pragma mark init
- (void)awakeFromNib {
	[statusItemController showStatusItem];
}

#pragma mark app delegate notification methods
- (void)showMainApplicationWindow {
	//[self _simulateCrash];
}
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
	
	// TMS bindings & notifications
	NSArray *tmsBindings = [NSArray arrayWithObjects:
							Property(rollingPeriodInterval),
							Property(fixedPeriodRestartDate),
							Property(monitoringMode),
							Property(includeInterfaces),
							@"monitoring", nil];
	for (NSString *bindingKey in tmsBindings)
		[[AKTrafficMonitorService sharedService]
		  bind:bindingKey 
	  toObject:[NSUserDefaultsController sharedUserDefaultsController] 
   withKeyPath:[@"values." stringByAppendingString:bindingKey]
	   options:nil];
	[[AKTrafficMonitorService sharedService] addObserver:self selector:@selector(_didReceiveNotificationFromTrafficMonitorService:)];
	
	// LS bindings & notifications
	NSArray *lsBindings = [NSArray arrayWithObjects:
						   @"tracking", nil];
	for (NSString *bindingKey in lsBindings)
		[[AKLandmarkManager sharedManager]
		   bind:bindingKey
	   toObject:[NSUserDefaultsController sharedUserDefaultsController]
	withKeyPath:[@"values." stringByAppendingString:bindingKey]
		options:nil];
	// custom binding
	[[AKLandmarkManager sharedManager]
		bind:Property(landmarks)
	toObject:[NSUserDefaultsController sharedUserDefaultsController]
 withKeyPath:@"values.landmarks"
	 options:[NSDictionary dictionaryWithObject:NSKeyedUnarchiveFromDataTransformerName
										 forKey:NSValueTransformerNameBindingOption]];
	[[AKLandmarkManager sharedManager] addObserver:self selector:@selector(_didReceiveNotificationFromLocationManager:)];
	
	// threshold notifications
	[self refreshThresholds];
	[GrowlApplicationBridge setGrowlDelegate:self];
}
- (void)applicationDidResignActive:(NSNotification *)notification {
#ifndef DEBUG
	[self dismissStatusWindow:self];
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
	return fPoint;
}
- (void)showPreferencesWindow:(id)sender {
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
	if (!preferencesWindowController)
	{
		preferencesWindowController = [[TBPreferencesWindowController alloc] init];
		
		// bindings
		NSArray *bindings = [NSArray arrayWithObjects:
							 Property(includeInterfaces), nil];
		for (NSString *bindingKey in bindings)
			[preferencesWindowController bind:bindingKey
									 toObject:[NSUserDefaultsController sharedUserDefaultsController]
								  withKeyPath:[@"values." stringByAppendingString:bindingKey]
									  options:nil];
		[preferencesWindowController bind:Property(interfaces)
								 toObject:[AKTrafficMonitorService sharedService]
							  withKeyPath:Property(interfaces)
								  options:nil];
	}
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
	if (!statusWindowController) {
		statusWindowController = [[TBStatusWindowController alloc] initWithWindowNibName:@"TBStatusWindow"];
		[statusWindowController bind:Property(shouldAnimateGauge) 
							toObject:[NSUserDefaultsController sharedUserDefaultsController] 
						 withKeyPath:[@"values." stringByAppendingString:Property(shouldAnimateGauge)]
							 options:nil];
	}
	[statusWindowController show:sender animate:BOOLDefaults(shouldAnimateWindowTransitions)];
}
- (void)dismissStatusWindow:(id)sender {
	[statusWindowController dismiss:sender];
	[statusItemController dismissHighlight:sender];
}
- (void)showGraphWindow:(id)sender {
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
	if (!graphWindowController)
		graphWindowController = [[TBGraphWindowController alloc] initWithWindowNibName:@"TBGraphWindow"];
	[graphWindowController flip:sender fromWindow:statusWindowController.window animate:BOOLDefaults(shouldAnimateWindowTransitions)];
}
- (void)dismissGraphWindow:(id)sender {
	[graphWindowController dismiss:sender];
	[statusItemController dismissHighlight:sender];
}

#pragma mark -
#pragma mark thresholds
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
	NSArray* notifications = [NSArray arrayWithObjects:
							  LOCATION_CHANGED,
							  LIMIT_REMINDER,
							  LIMIT_EXCEEDED,
							  ERROR_MESSAGE,
							  nil];
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
								   isSticky:BOOLDefaults(notificationIsSticky)
							   clickContext:name];
	DLog(@"Growl {\n\t\"%@\",\n\t\"%@\",\n\t\"%@\"\n}", title, description, name);
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
			
			if (BOOLDefaults(shouldNotify)) {
				// send notification
				float criticalPercentage = [Defaults(criticalPercentage) floatValue];
				NSString *title = [NSString stringWithFormat:
								   NSLocalizedString(@"You have used %.0f%% of your limit.", LIMIT_REMINDER),
								   criticalPercentage];
				[self _sendGrowlNotificationWithTitle:title description:nil notificationName:LIMIT_REMINDER];
			}
			if (BOOLDefaults(shouldRun)) {
				// run executable file
				NSString *urlString = Defaults(runURL);
				NSString *ext = [urlString pathExtension];
				if ([ext isEqual:@"scpt"]) {
					NSAppleScript *script = [[[NSAppleScript alloc] initWithContentsOfURL:[NSURL fileURLWithPath:urlString] error:NULL] autorelease];
					[script executeAndReturnError:NULL];
				}
				else {
					[[NSWorkspace sharedWorkspace] openFile:urlString];
				}
			}
		}
		else if ([context isEqual:LIMIT_EXCEEDED]) {
			
			if (BOOLDefaults(shouldNotify)) {
				// send notification
				NSString *title = NSLocalizedString(@"You have used all of your limit.", LIMIT_EXCEEDED);
				[self _sendGrowlNotificationWithTitle:title description:nil notificationName:LIMIT_EXCEEDED];
			}
		}	
	}
}

#pragma mark -
#pragma mark landmark manager notifications
- (void)_didReceiveNotificationFromLocationManager:(NSNotification *)notification
{
    DLog(@"received: %@", notification);

	if (!BOOLDefaults(tracking)) return;

    NSString *title = nil;
    NSString *description = nil;
    NSString *noteName = nil;
    if ([[notification name] isEqual:AKLandmarkManagerDidGetNewLandmarkNotification])
    {
		BOOL nearby = [[AKLandmarkManager sharedManager] hasNearbyLandmarks];
		SetBOOLDefaults(nearby, monitoring);

        // growl
		if (!BOOLDefaults(shouldNotifyOnLocation)) return;
		if (nearby)
		{
			title = [NSString stringWithFormat:
					 NSLocalizedString(@"You're now at \"%@\"", @"location changed"),
					 [[[AKLandmarkManager sharedManager] landmark] name]];
		}
		else
		{
			title = NSLocalizedString(@"You're not at any saved location.", @"location changed");
			description = NSLocalizedString(@"TrafficBot will pause monitoring for now.", @"location changed");
		}
        noteName = LOCATION_CHANGED;
    }
    else if ([[notification name] isEqual:AKLandmarkManagerDidFailNotification])
    {
        // growl
		if (!BOOLDefaults(shouldNotifyOnError)) return;
		title = NSLocalizedString(@"Could not determine your location.", @"location fail");
        description = NSLocalizedString(@"OS X does not know your current location.", @"location fail");
		noteName = ERROR_MESSAGE;
    }

    if (IsEmpty(title) || IsEmpty(noteName)) return;
    [self _sendGrowlNotificationWithTitle:title description:description notificationName:noteName];
}

#pragma mark -
#pragma simulate crash
- (void)_simulateCrash
{
	((void (*)())0)();
}

@end
