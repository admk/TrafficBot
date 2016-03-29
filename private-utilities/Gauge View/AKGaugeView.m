//
//  AKGaugeView.m
//  GaugeView
//
//  Created by Adam Ko on 26/10/2010.
//  Copyright 2010 Loca Apps. All rights reserved.
//

#import "AKGaugeView.h"
#import "APDrawingCategories.h"
#import "NSFont+AKFallback.h"


@interface AKGaugeView (Private)
- (void)_updatePercentage:(id)info;
@end

@implementation AKGaugeView
#pragma mark -
#pragma mark init & dealloc
- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
	_percentage = 200;
	_criticalPercentage = 100;
	_animatedPercentage = 0;
	_frameCount = 0;
    return self;
}
- (void)dealloc {
	[_percentageAnimationTimer invalidate], _percentageAnimationTimer = nil;
	[_gaugeImage release], _gaugeImage = nil;
	[_gaugePointerView release], _gaugePointerView = nil;
	[super dealloc];
}

#pragma mark -
#pragma mark NSView specific
- (void)awakeFromNib {
	NSImage *pointerImage = [NSImage imageNamed:@"Gauge Pointer.png"];
	NSRect pointerViewRect = NSMakeRect(73, -86, pointerImage.size.width, pointerImage.size.height);
	_gaugePointerView = [[NSImageView alloc] initWithFrame:pointerViewRect];
	[_gaugePointerView setImage:pointerImage];
	[self addSubview:_gaugePointerView];
	[self setPercentage:0 animated:NO];
}
- (void)drawRect:(NSRect)dirtyRect {
	if (!_gaugeImage) _gaugeImage = [[NSImage imageNamed:@"Gauge Face.png"] retain];
	[_gaugeImage drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1];

	NSString *pString = [NSString stringWithFormat:@"%.0f%%", _animatedPercentage];
	NSFont *psFont = [NSFont ak_fontWithName:@"Helvetica Neue Bold" size:30];
	NSBezierPath *psPath = [pString bezierWithFont:psFont];
	NSAffineTransform *xform = [NSAffineTransform transform];

	// shadow by filling path
	[xform translateXBy:75 - psPath.bounds.size.width / 2 yBy:37];
	[xform concat];
	if (_animatedPercentage >= self.criticalPercentage)
		[[NSColor colorWithCalibratedRed:0.5f green:0 blue:0 alpha:1] set];
	else
		[[NSColor blackColor] set];
	[psPath fill];

	[xform translateXBy:-(75 - psPath.bounds.size.width / 2) yBy:-38];
	[xform concat];
	// gradient
	NSColor *gradientColor1, *gradientColor2;
	if (_animatedPercentage >= self.criticalPercentage) {
		gradientColor1 = [NSColor colorWithCalibratedRed:1.0f green:0 blue:0 alpha:1];
		gradientColor2 = [NSColor colorWithCalibratedRed:1.0f green:128.0f/255.0f blue:128.0f/255.0f alpha:1];
	}
	else {
		gradientColor1 = [NSColor blackColor];
		gradientColor2 = [NSColor grayColor];
	}
	NSGradient* pGradient = [[[NSGradient alloc] initWithColorsAndLocations:
							  gradientColor1, (CGFloat)0.0,
							  gradientColor2, (CGFloat)1.0,
							  nil] autorelease];
	[pGradient drawInBezierPath:psPath angle:-90.0];
}

#pragma mark -
#pragma mark setters & getters

#pragma mark animation
#define ANIMATION_FRAMES 15
- (void)setPercentage:(float)value {
	[self setPercentage:value animated:YES];
}
- (void)setPercentage:(float)value animated:(BOOL)isAnimated {

	if (-.5 < (value - _percentage) && (value - _percentage) < .5) return;

	ZAssert(value <= 100, @"percentage must be less than 100");

	float lastPercentage = _percentage;
	_percentage = value;
	float rotationAngle = 180.0f - 70.5f - _percentage / 100.0f * 44.0f;

	BOOL shouldAnimate = (_percentage - lastPercentage) < -2 || (_percentage - lastPercentage) > 2;
	if (!isAnimated && shouldAnimate) {
		_animatedPercentage = _percentage;
		_increment = 0;
		[self _updatePercentage:nil];
		[_gaugePointerView setFrameRotation:rotationAngle];
		return;
	}
	// isAnimated
	_increment = (_percentage - lastPercentage)/ANIMATION_FRAMES;
	_animatedPercentage = lastPercentage;

	// timer
	[_percentageAnimationTimer invalidate], _percentageAnimationTimer = nil;
	_percentageAnimationTimer = [NSTimer scheduledTimerWithTimeInterval:0.15/ANIMATION_FRAMES target:self selector:@selector(_updatePercentage:) userInfo:nil repeats:YES];
	[_percentageAnimationTimer fire];

	// pointer
	[[_gaugePointerView animator] setFrameRotation:rotationAngle];
}

@synthesize percentage = _percentage, criticalPercentage = _criticalPercentage;
@end

#pragma mark -
#pragma mark private
@implementation AKGaugeView (Private)
- (void)_updatePercentage:(id)info {
	if (_frameCount++ < ANIMATION_FRAMES) {
		_animatedPercentage += _increment;
		if (_animatedPercentage < 0)	_animatedPercentage = 0;
		if (_animatedPercentage > 100)  _animatedPercentage = 100;
		[self setNeedsDisplay:YES];
		if ([self.window isVisible]) return;
	}
	// animation end
	[_percentageAnimationTimer invalidate], _percentageAnimationTimer = nil;
	_frameCount = 0;
}
@end
