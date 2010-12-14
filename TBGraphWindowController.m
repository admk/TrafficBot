//
//  TBGraphWindowController.m
//  TrafficBot
//
//  Created by Adam Ko on 13/12/2010.
//  Copyright 2010 Imperial College. All rights reserved.
//

#import "TBGraphWindowController.h"
#import "AKTrafficMonitorService.h"
#import "MAAttachedWindow.h"
#import "NSWindow+AKFlip.h"
#import "NSWindow+NoodleEffects.h"

@interface TBGraphWindowController ()
- (void)_refresh;
- (void)_didReceiveNotificationFromTrafficMonitorService:(NSNotification *)notification;
@end

@implementation TBGraphWindowController

- (void)awakeFromNib {
	[[AKTrafficMonitorService sharedService] addObserver:self selector:@selector(_didReceiveNotificationFromTrafficMonitorService:)];
	[self _refresh];
}

#pragma mark -
- (void)flip:(id)sender fromWindow:(NSWindow *)aWindow atPoint:(NSPoint)point {
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
	[self _refresh];
	// shows graph view
	_zoomRect = [sender convertRect:[sender bounds] toView:nil];
	_zoomRect.origin = point;
	if (!self.window) {
		MAAttachedWindow *window = [[MAAttachedWindow alloc] initWithView:self.graphView 
											 attachedToPoint:_zoomRect.origin 
													inWindow:nil 
													  onSide:MAPositionBottom 
												  atDistance:3.0];
		[window setArrowHeight:10];
		[window setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
		[window setAcceptsMouseMovedEvents:YES];
		self.window = window;
	}
	else {
		[(MAAttachedWindow *)self.window setPoint:point];
	}
	[aWindow flipToWindow:self.window];
	[self.window makeFirstResponder:self.graphView];
}
- (void)dismiss:(id)sender {
	[self.window zoomOffToRect:_zoomRect];
}

#pragma mark -
#pragma mark events


#pragma mark -
#pragma mark private
#pragma mark refresh view
- (void)_refresh {
	// calculate total
	NSDictionary *dict = [[AKTrafficMonitorService sharedService] rollingLogFile];
	NSMutableDictionary *graphDict = [[[NSMutableDictionary alloc] initWithCapacity:[dict count]] autorelease];
	for (NSString *dateString in [dict allKeys]) {
		NSDictionary *inOutDict = [dict objectForKey:dateString];
		double total = [[inOutDict objectForKey:@"in"] doubleValue] + [[inOutDict objectForKey:@"out"] doubleValue];
		[graphDict setObject:[NSNumber numberWithDouble:total] forKey:[NSDate dateWithString:dateString]];
	}
	self.graphView.dataDict = graphDict;
}
#pragma mark monitor service notifications
- (void)_didReceiveNotificationFromTrafficMonitorService:(NSNotification *)notification {
	if ([[notification name] isEqual:AKTrafficMonitorStatisticsDidUpdateNotification]) {
		if (![self.window isVisible]) return;
		[self _refresh];
	}
}
@synthesize graphView, contentView, draggedPanel;
@end
