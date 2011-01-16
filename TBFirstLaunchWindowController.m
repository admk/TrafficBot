//
//  TBFirstLaunchWindowController.m
//  TrafficBot
//
//  Created by Adam Ko on 16/01/2011.
//  Copyright 2011 Imperial College. All rights reserved.
//

#import "TBFirstLaunchWindowController.h"
#import "TBSetupView.h"
#import "MAAttachedWindow.h"
#import "NSWindow+NoodleEffects.h"
#import "TrafficBotAppDelegate.h"

@implementation TBFirstLaunchWindowController

#pragma mark -
#pragma mark nib loading
- (void)awakeFromNib {
	_setupView = [[TBSetupView alloc] initWithFrame:self.contentView.bounds];
	_setupView.infoString = NSLocalizedString(@"Welcome! I live up here.", @"welcome");
	_setupView.backgroundColor = [NSColor clearColor];
	[self.contentView addSubview:_setupView];
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
																atDistance:25.0f] autorelease];
		[window setArrowHeight:10];
		[window setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
		[window setLevel:NSFloatingWindowLevel];
		self.window = window;
		// force window on screen to avoid glitch
		[window setAlphaValue:0];
		[window orderFront:sender];
		[window orderOut:sender];
		[window setAlphaValue:1];
	}
	[(MAAttachedWindow *)self.window setPoint:[[NSApp delegate] statusItemPoint]];
	[self.window zoomOnFromRect:[[NSApp delegate] statusItemFrame]];
}
- (void)dismiss:(id)sender {
	[self.window zoomOffToRect:[[NSApp delegate] statusItemFrame]];
}

@synthesize contentView;
@end
