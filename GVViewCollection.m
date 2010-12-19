//
//  GVViewCollection.m
//  TrafficBot
//
//  Created by Adam Ko on 19/12/2010.
//  Copyright 2010 Imperial College. All rights reserved.
//

#import "GVViewCollection.h"

@implementation GVPegView
- (void)drawRect:(NSRect)dirtyRect {
    // peg
    NSBezierPath* pegPath = [NSBezierPath bezierPath];
    [pegPath appendBezierPathWithOvalInRect:NSInsetRect(self.bounds, 5, 5)];
    // shadow
    NSShadow *pegShadow = [[[NSShadow alloc] init] autorelease];
    [pegShadow setShadowColor:[NSColor blackColor]];
    [pegShadow setShadowOffset:NSMakeSize(0, -2)];
    [pegShadow setShadowBlurRadius:4];
    [pegShadow set];
    [pegPath fill];
    // stroke
    [[NSColor whiteColor] set];
    [pegPath setLineWidth:4];
    [pegPath stroke];
    // fill
    NSColor *pegColor1 = [NSColor colorWithCalibratedRed:0 green:180.0/255 blue:1 alpha:1];
    NSColor *pegColor2 = [NSColor colorWithCalibratedRed:0 green:70.0/255 blue:125.0/255 alpha:1];
    NSGradient* gradient = [[[NSGradient alloc] initWithColorsAndLocations:
                             pegColor1, (CGFloat)0.0, pegColor2, (CGFloat)1.0, nil] autorelease];
    [gradient drawInBezierPath:pegPath angle:-90.0];
}
@end

@implementation GVIndicatorView
- (void)drawRect:(NSRect)dirtyRect {
	// path
	NSBezierPath* path = [NSBezierPath bezierPath];
	[path moveToPoint:NSMakePoint(10, 0)];
	[path lineToPoint:NSMakePoint(10, self.bounds.size.height - 10)];
	// shadow
	NSShadow *aShadow = [[[NSShadow alloc] init] autorelease];
	[aShadow setShadowColor:[NSColor blackColor]];
	[aShadow setShadowOffset:NSMakeSize(0, -2)];
	[aShadow setShadowBlurRadius:4];
	[aShadow set];
	[path fill];
	// stroke
	[[NSColor colorWithCalibratedRed:100.0/255 green:200.0/255 blue:1 alpha:1] set];
	[path setLineWidth:2];
	[path stroke];
}
@end
