//
//  TBGraphWindowController.m
//  TrafficBot
//
//  Created by Adam Ko on 13/12/2010.
//  Copyright 2010 Imperial College. All rights reserved.
//

#import "TBGraphWindowController.h"
#import "AKTrafficMonitorService.h"
#import "TrafficBotAppDelegate.h"
#import "MAAttachedWindow.h"
#import "NSWindow+AKFlip.h"
#import "NSWindow+NoodleEffects.h"

@interface TBGraphWindowController ()
@property (retain) NSWindow *_flipFromWindow;
- (void)_refreshView:(TBGraphView *)view;
- (void)_didReceiveNotificationFromTrafficMonitorService:(NSNotification *)notification;
@end

@implementation TBGraphWindowController

- (void)dealloc {
	self._flipFromWindow = nil;
	[super dealloc];
}

- (void)awakeFromNib {
	[draggedPanel setLevel:NSNormalWindowLevel];
	[draggedPanel setAcceptsMouseMovedEvents:YES];
	[draggedPanel setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];	
	[self _refreshView:self.graphView];
	[[AKTrafficMonitorService sharedService] addObserver:self selector:@selector(_didReceiveNotificationFromTrafficMonitorService:)];
}

#pragma mark -
#pragma mark ui
- (void)flip:(id)sender fromWindow:(NSWindow *)aWindow {
	[self _refreshView:self.graphView];
	// shows graph view
	if ([[self.window class] isNotEqualTo:[MAAttachedWindow class]]) {
		MAAttachedWindow *window = [[[MAAttachedWindow alloc] initWithView:self.contentView 
														   attachedToPoint:[[NSApp delegate] statusItemPoint]
																  inWindow:nil 
																	onSide:MAPositionBottom 
																atDistance:3.0f] autorelease];
		[window setBackgroundImage:[NSImage imageNamed:@"GraphWindowBackground.png"]];
		[window setArrowHeight:10];
		[window setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
		[window setLevel:NSFloatingWindowLevel];
		[window setAcceptsMouseMovedEvents:YES];
		self.window = window;
	}
	else {
		[(MAAttachedWindow *)self.window setPoint:[[NSApp delegate] statusItemPoint]];
	}
	[aWindow flipToWindow:self.window];
	self._flipFromWindow = aWindow;
	[self.window makeFirstResponder:self.graphView];
}
- (void)dismiss:(id)sender {
	[self.window zoomOffToRect:[[NSApp delegate] statusItemFrame]];
}
- (IBAction)flipBack:(id)sender {
	[self.window flipBackToWindow:self._flipFromWindow];
}
#pragma mark -
#pragma mark protocol
- (void)showDraggedWindowWithFrame:(NSRect)frame {
	[draggedPanel makeFirstResponder:self.draggedGraphView];
	[draggedPanel setFrame:frame display:NO];
	[draggedPanel makeKeyAndOrderFront:self];
	[[NSApp delegate] dismissGraphWindow:self];
	[self _refreshView:self.draggedGraphView];
}

#pragma mark -
#pragma mark private
#pragma mark refresh view
- (void)_refreshView:(TBGraphView *)view {
	// calculate total
	NSDictionary *dict = [[AKTrafficMonitorService sharedService] rollingLogFile];
	NSMutableDictionary *graphDict = [[[NSMutableDictionary alloc] initWithCapacity:[dict count]] autorelease];
	for (NSString *dateString in [dict allKeys]) {
		[graphDict setObject:[dict objectForKey:dateString] forKey:[NSDate dateWithString:dateString]];
	}
	view.dataDict = graphDict;
}
#pragma mark monitor service notifications
- (void)_didReceiveNotificationFromTrafficMonitorService:(NSNotification *)notification {
	if ([[notification name] isEqual:AKTrafficMonitorStatisticsDidUpdateNotification]) {
		if ([self.window isVisible]) {
			[self _refreshView:self.graphView];
		}
		if ([self.draggedPanel isVisible]) {
			[self _refreshView:self.draggedGraphView];	
		}
	}
}
@synthesize graphView, contentView, draggedPanel, draggedGraphView;
@synthesize _flipFromWindow;
@end
