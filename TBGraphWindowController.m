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
#import "NSWindow-NoodleEffects.h"

@interface TBGraphWindowController ()
@property (retain) NSWindow *_flipFromWindow;
- (void)_refreshView;
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
	[self _refreshView];
	[[AKTrafficMonitorService sharedService] addObserver:self selector:@selector(_didReceiveNotificationFromTrafficMonitorService:)];
	[self.graphView bind:Property(logScale)
				toObject:[NSUserDefaultsController sharedUserDefaultsController]
			 withKeyPath:[@"values." stringByAppendingString:Property(logScale)]
				 options:nil];
}

#pragma mark -
#pragma mark ui
- (void)flip:(id)sender fromWindow:(NSWindow *)aWindow animate:(BOOL)animate {
    
	[draggedPanel orderOut:sender];
	
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
	
	// animation
	_animate = animate;
	self._flipFromWindow = aWindow;
	if (_animate) {
		[aWindow flipToWindow:self.window];
	}
	else {
		[aWindow orderOut:sender];
		[self.window makeKeyAndOrderFront:sender];
	}
	
	if (![[self.contentView subviews] containsObject:self.graphView]) {
		NSRect viewRect = self.contentView.bounds;
		viewRect.size.height -= 20;
		self.graphView.frame = viewRect;
		[self.contentView addSubview:self.graphView];
	}
	[self _refreshView];
	
	// graph view accepts mouse events
	[self.window makeFirstResponder:self.graphView];
}
- (void)dismiss:(id)sender {
	if (_animate) {
		[self.window zoomOffToRect:[[NSApp delegate] statusItemFrame]];
	}
	else {
		[self.window orderOut:sender];
	}
}
- (IBAction)flipBack:(id)sender {
	if (_animate) {
		[self.window flipBackToWindow:self._flipFromWindow];
	}
	else {
		[self.window orderOut:sender];
		[self._flipFromWindow makeKeyAndOrderFront:sender];
	}
}
#pragma mark -
#pragma mark protocol
- (void)showDraggedWindowWithFrame:(NSRect)frame {
	[draggedPanel setFrame:frame display:YES];
	draggedPanel.contentView = self.graphView;
	[draggedPanel makeFirstResponder:self.graphView];
	[draggedPanel makeKeyAndOrderFront:self];
	[[NSApp delegate] dismissGraphWindow:self];
	[self _refreshView];
}

#pragma mark -
#pragma mark private
#pragma mark refresh view
- (void)_refreshView {
	// calculate total
	NSDictionary *dict = [[AKTrafficMonitorService sharedService] rollingLogFile];
	NSMutableDictionary *graphDict = [[[NSMutableDictionary alloc] initWithCapacity:[dict count]] autorelease];
	for (NSString *dateString in [dict allKeys]) {
		[graphDict setObject:[dict objectForKey:dateString] forKey:[NSDate dateWithString:dateString]];
	}
	graphView.dataDict = graphDict;
}
#pragma mark monitor service notifications
- (void)_didReceiveNotificationFromTrafficMonitorService:(NSNotification *)notification {
	if ([[notification name] isEqual:AKTrafficMonitorLogsDidUpdateNotification]) {
		if ([self.graphView.window isVisible]) {
			[self _refreshView];
		}
	}
}
@synthesize graphView, contentView, draggedPanel;
@synthesize _flipFromWindow;
@end
