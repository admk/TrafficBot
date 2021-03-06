//
//  StatusItemController.m
//  Serenitas
//
//  Created by Adam Ko on 11/08/2010.
//  Copyright (c) 2010 Loca Apps. All rights reserved.
//

#ifdef DEBUG_FSCRIPT
#import <FScript/FScript.h>
#endif
#import "TBStatusItemController.h"
#import "AKTrafficMonitorService.h"
@interface TBStatusItemController ()
- (void)_refreshStatusItemView;
- (void)_didReceiveNotificationFromTrafficMonitorService:(NSNotification *)notification;
@end

@implementation TBStatusItemController

#pragma mark -
#pragma mark init & dealloc
- (id)init {
	self = [super init];
	if (!self) return nil;
	return self;
}
- (void)dealloc {
	[statusItemView release], statusItemView = nil;
	[statusItem release], statusItem = nil;
	[super dealloc];
}

#pragma mark -
#pragma mark setters & getters
- (void)setLimit:(NSNumber *)newLimit {
	if ([_limit isEqualToNumber:newLimit]) return;
	[_limit release];
	_limit = [newLimit retain];
	[self _refreshStatusItemView];
}

#pragma mark -
#pragma mark UI methods
- (void)showStatusItem {
	// status item
	float width = 29.0f;
    float height = (float)[[NSStatusBar systemStatusBar] thickness];
    NSRect viewFrame = NSMakeRect(0, 0, width, height);
	self.statusItemView = [[[TBStatusItemView alloc] initWithFrame:viewFrame controller:self] autorelease];
    statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:width] retain];
    [statusItem setView:statusItemView];

	// bindings & notifications
	[[AKTrafficMonitorService sharedService] addObserver:self selector:@selector(_didReceiveNotificationFromTrafficMonitorService:)];
	[self bind:Property(limit) 
	  toObject:[NSUserDefaultsController sharedUserDefaultsController] 
   withKeyPath:[@"values." stringByAppendingString:Property(limit)]
	   options:nil];
	NSArray *bindings = [NSArray arrayWithObjects:@"monitoring", Property(criticalPercentage), nil];
	for (NSString *bindingKey in bindings)
		[self.statusItemView bind:bindingKey
						 toObject:[NSUserDefaultsController sharedUserDefaultsController]
					  withKeyPath:[@"values." stringByAppendingString:bindingKey]
						  options:nil];
}
- (void)showMenu:(id)sender {
#ifdef DEBUG_FSCRIPT
	static FScriptMenuItem *fsMenuItem = nil;
	if (!fsMenuItem)
	{
		fsMenuItem = [[FScriptMenuItem alloc] init];
		FSInterpreter *interpreter = [[fsMenuItem interpreterView] interpreter];
		[interpreter setObject:[NSApp delegate] forIdentifier:@"controller"];
		[menu addItem:fsMenuItem];
		[fsMenuItem release];
	}
#endif // DEBUG
	
	[statusItem performSelector:@selector(popUpStatusItemMenu:) withObject:menu afterDelay:0.0f];
}
- (IBAction)about:(id)sender {
	[[NSApplication sharedApplication] orderFrontStandardAboutPanel:sender];
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
}
- (void)dismissHighlight:(id)sender {
	[self.statusItemView dismissHighlight:sender];
}

#pragma mark -
#pragma mark private
#pragma mark ui
- (void)_refreshStatusItemView {
	// update display
	NSNumber *totalIn = [[AKTrafficMonitorService sharedService] totalIn];
	NSNumber *totalOut = [[AKTrafficMonitorService sharedService] totalOut];
	if ([self.limit unsignedLongLongValue] == 0) {
		self.statusItemView.percentage = 0;
	}
	else {
		TMS_D_T ullTotal = TMSDTFromNumber(totalIn) + TMSDTFromNumber(totalOut);
		float percentage = (float)ullTotal / [self.limit floatValue] * 100;
		if (percentage > 100) {
			self.statusItemView.percentage = 100;
			return;
		}
		self.statusItemView.percentage = percentage;
	}	
}

#pragma mark monitor service notifications
- (void)_didReceiveNotificationFromTrafficMonitorService:(NSNotification *)notification {
	if ([[notification name] isEqual:AKTrafficMonitorStatisticsDidUpdateNotification] ||
		[[notification name] isEqual:AKTrafficMonitorLogsDidUpdateNotification]) {
		// stats did update
		[self _refreshStatusItemView];
	}
}

@synthesize statusItemView;
@synthesize limit = _limit;
@end
