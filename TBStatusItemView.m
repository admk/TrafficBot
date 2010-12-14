//
//  TBStatusItemView.m
//  TrafficBot
//
//  Created by Adam Ko on 25/10/2010.
//  Copyright (c) 2010 Cocoa Loco. All rights reserved.
//

#import "TBStatusItemView.h"
#import "TrafficBotAppDelegate.h"

@implementation TBStatusItemView


#pragma mark init
- (id)initWithFrame:(NSRect)frame controller:(id)inController {
	self = [super initWithFrame:frame];
    if (!self) return nil;
    // initialisation goes here...
	controller = inController;
    return self;
}


#pragma mark -
#pragma mark drawing
- (void)drawRect:(NSRect)rect {
    // draw background if appropriate
    if (_highlighted) {
        [[NSColor selectedMenuItemColor] set];
        NSRectFill(rect);
    }
	NSImage *statusItemImage = [NSImage imageNamed:_highlighted ? @"Status Icon.png" : @"Status Icon.png"];
	NSSize itemSize = [statusItemImage size];
    NSRect itemRect = NSMakeRect(0, 0, itemSize.width, itemSize.height);
    itemRect.origin.x = (int)(([self frame].size.width - itemSize.width) / 2.0);
    itemRect.origin.y = (int)(([self frame].size.height - itemSize.height) / 2.0);
	[statusItemImage drawInRect:itemRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1];
}

#pragma mark -
#pragma mark events
- (void)mouseDown:(NSEvent *)theEvent {
    if (_highlighted) {
		[self dismissHighlight:nil];
		[[NSApp delegate] dismissStatusView:nil];
		[[NSApp delegate] dismissGraphWindow:nil];
	}
	else {
		[self highlight:nil];
		NSRect frame = [[self window] frame];
		NSPoint point = NSMakePoint(NSMidX(frame), NSMinY(frame));
		[[NSApp delegate] showStatusView:self atPoint:point];
    }
}
- (void)rightMouseDown:(NSEvent *)theEvent {
	[controller showMenu:self];
}

#pragma mark -
- (void)highlight:(id)sender {
	_highlighted = YES;
    [self setNeedsDisplay:YES];
}
- (void)dismissHighlight:(id)sender {
	_highlighted = NO;
	[self setNeedsDisplay:YES];
}

@synthesize controller;
@end
