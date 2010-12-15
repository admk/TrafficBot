//
//  TBStatusItemView.m
//  TrafficBot
//
//  Created by Adam Ko on 25/10/2010.
//  Copyright (c) 2010 Cocoa Loco. All rights reserved.
//

#import "TBStatusItemView.h"
#import "TrafficBotAppDelegate.h"

#pragma mark private
@interface TBStatusItemView ()
- (NSBezierPath *)_appendGaugeGlyphToPath:(NSBezierPath *)path 
								withFrame:(NSRect)frame 
									theta:(float)theta 
								   lambda:(float)lambda 
									inset:(float)inset 
								 atHeight:(float)yOffset;
@end

#pragma mark -
@implementation TBStatusItemView
#pragma mark init
- (id)initWithFrame:(NSRect)frame controller:(id)inController {
	self = [super initWithFrame:frame];
    if (!self) return nil;
    // initialisation goes here...
	controller = inController;
	_monitoring = NO;
	_percentage = 0;
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
	NSBezierPath *path = [NSBezierPath bezierPath];
	path = [self _appendGaugeGlyphToPath:path withFrame:self.bounds theta:30 lambda:30 inset:4 atHeight:-1];
	path = [self _appendGaugeGlyphToPath:path withFrame:self.bounds theta:30 lambda:30-(self.percentage/100*30*2) inset:7 atHeight:0];
	[path setWindingRule:NSEvenOddWindingRule];
	
	if (!self.monitoring) {
		// gradient fill
		[[NSColor colorWithCalibratedWhite:.5 alpha:.5] set];
		[path fill];
		return;
	}
	
	if (_highlighted) {
		[[NSColor whiteColor] set];
		[path fill];
	}
	else {
		// shadow
		NSShadow *shadow = [[NSShadow alloc] init];
		[shadow setShadowOffset:NSMakeSize(0, -1)];
		[shadow setShadowBlurRadius:0];
		[shadow setShadowColor:[NSColor colorWithCalibratedWhite:1 alpha:.5]];
		[shadow set];
		[path fill];
		// gradient fill
		NSGradient *gradient = [[[NSGradient alloc] initWithStartingColor:[NSColor blackColor] endingColor:[NSColor darkGrayColor]] autorelease];
		[gradient drawInBezierPath:path angle:-90];
	}
}
#pragma mark -
#pragma mark events
- (void)mouseDown:(NSEvent *)theEvent {
    if (_highlighted) {
		[self dismissHighlight:nil];
		[[NSApp delegate] dismissStatusWindow:nil];
		[[NSApp delegate] dismissGraphWindow:nil];
	}
	else {
		[self highlight:nil];
		NSRect frame = [[self window] frame];
		NSPoint point = NSMakePoint(NSMidX(frame), NSMinY(frame));
		[[NSApp delegate] showStatusWindow:self atPoint:point];
    }
}
- (void)rightMouseDown:(NSEvent *)theEvent {
	[controller showMenu:self];
}
#pragma mark -
#pragma mark highlight
- (void)highlight:(id)sender {
	_highlighted = YES;
    [self setNeedsDisplay:YES];
}
- (void)dismissHighlight:(id)sender {
	_highlighted = NO;
	[self setNeedsDisplay:YES];
}

#pragma mark -
#pragma mark setters & getters
- (void)setMonitoring:(BOOL)inBool {
	_monitoring = inBool;
	[self setNeedsDisplay:YES];
}
- (void)setPercentage:(float)newPercentage {
	_percentage = newPercentage;
	[self setNeedsDisplay:YES];
}

#pragma mark -
#pragma mark private
- (NSBezierPath *)_appendGaugeGlyphToPath:(NSBezierPath *)path 
								withFrame:(NSRect)frame 
									theta:(float)theta 
								   lambda:(float)lambda 
									inset:(float)inset 
								 atHeight:(float)yOffset {
	// math
	float width = frame.size.width - inset * 2;
	//float height = frame.size.height - inset * 2;
	float theta_rad = theta / 180 * pi;
	float radius = width / (2 * sinf(theta_rad));
	float radius_sin_factor = radius * sinf(theta_rad);
	float radius_cos_factor = radius * cosf(theta_rad);
	// points
	NSPoint center = { radius_sin_factor + inset, -radius_cos_factor/2 - yOffset + inset };
	NSPoint lowerRight = { 3 * radius_sin_factor / 2 + inset, inset - yOffset };
	// path
	[path moveToPoint:lowerRight];
	[path appendBezierPathWithArcWithCenter:center radius:radius startAngle:90-theta endAngle:90+lambda];
	[path appendBezierPathWithArcWithCenter:center radius:radius/2 startAngle:90+lambda endAngle:90-theta clockwise:YES];
	return path;
}
@synthesize controller;
@synthesize percentage = _percentage, monitoring = _monitoring;
@end
