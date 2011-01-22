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
	_criticalPercentage = 100;
    return self;
}
#pragma mark -
#pragma mark drawing
- (void)drawRect:(NSRect)rect {
    // draw background if highlighted
    if (_highlighted) {
        [[NSColor selectedMenuItemColor] set];
        NSRectFill(rect);
    }
	NSBezierPath *path = [NSBezierPath bezierPath];
	path = [self _appendGaugeGlyphToPath:path withFrame:self.bounds theta:30 lambda:30 inset:4 atHeight:-1];
	path = [self _appendGaugeGlyphToPath:path withFrame:self.bounds theta:30 lambda:30-(self.percentage/100*30*2) inset:7 atHeight:0];
	[path setWindingRule:NSEvenOddWindingRule];
	// draw disabled view if not monitoring
	if (!self.monitoring) {
		// gradient fill
		[[NSColor colorWithCalibratedWhite:.5 alpha:.5] set];
		[path fill];
		return;
	}
	// draw in white if highlighted
	if (_highlighted) {
		[[NSColor whiteColor] set];
		[path fill];
	}
	else {
		// shadow
		NSShadow *aShadow = [[[NSShadow alloc] init] autorelease];
		[aShadow setShadowOffset:NSMakeSize(0, -1)];
		[aShadow setShadowBlurRadius:0];
		[aShadow setShadowColor:[NSColor colorWithCalibratedWhite:1 alpha:.5]];
		[aShadow set];
		[path fill];
		// gradient fill
		NSGradient *gradient = [[[NSGradient alloc] initWithStartingColor:[NSColor blackColor] endingColor:[NSColor darkGrayColor]] autorelease];
		[gradient drawInBezierPath:path angle:-90];
		// critical drawing
		if (self.percentage >= self.criticalPercentage) {
			[[NSColor colorWithCalibratedRed:1.0f green:0 blue:0 alpha:.3] set];
			[path fill];
		}
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
		[[NSApp delegate] showStatusWindow:self];
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
	ZAssert(newPercentage <= 100, @"percentage must be less than 100");
	_percentage = newPercentage;
	[self setNeedsDisplay:YES];
}
- (void)setCriticalPercentage:(float)newPercentage {
	ZAssert(newPercentage <= 100, @"criticalPercentage must be less than 100");
	_criticalPercentage = newPercentage;
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
	float width = (float)frame.size.width - inset * 2.0f;
	//float height = frame.size.height - inset * 2;
	float theta_rad = theta / 180.0f * (float)pi;
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
@synthesize percentage = _percentage, criticalPercentage = _criticalPercentage;
@synthesize monitoring = _monitoring;
@end
