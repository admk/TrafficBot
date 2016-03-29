//
//  AKSummaryView.m
//  Summary View
//
//  Created by Adam Ko on 22/01/2011.
//  Copyright 2011 Imperial College. All rights reserved.
//

#import "AKSummaryView.h"
#import "APDrawingCategories.h"
#import "NSFont+AKFallback.h"


@implementation AKSummaryView


- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;

    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
	if (_backgroundImage)
	{
		[_backgroundImage drawInRect:[self bounds] fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1];
	}

	if (!self.summaryString)
	{
		self.summaryString = @"Hello and welcome!\nLorem Ipsum.";
	}

	NSFont *stringFont = [NSFont ak_fontWithName:@"Georgia Italic" size:20];
	NSBezierPath *stringPath = [self.summaryString bezierWithFont:stringFont];

	NSAffineTransform *transform = [NSAffineTransform transform];
	[transform translateXBy:(self.bounds.size.width / 2 - stringPath.bounds.size.width / 2)
					yBy:(self.bounds.size.height / 2 - stringPath.bounds.size.height / 2)];
	[transform concat];

	// shadow
	if (_shadow)
	{
		[NSGraphicsContext saveGraphicsState];
		[_shadow set];
		[stringPath fill];
		[NSGraphicsContext restoreGraphicsState];
	}

	// fill
	if (!_textColor)
	{
		[self setTextColor:[NSColor darkGrayColor]];
	}
	[_textColor set];
	[stringPath fill];
}


#pragma mark -
#pragma mark setters & getters

- (void)setSummaryString:(NSString *)string
{
	if (string != _summaryString)
	{
		[_summaryString release];
		_summaryString = [string retain];
	}
	[self setNeedsDisplay:YES];
}

- (NSImage *)backgroundImage
{
	return _backgroundImage;
}

- (void)setBackgroundImage:(NSImage *)image
{
	if (image == _backgroundImage) return;

	[_backgroundImage release];
	_backgroundImage = [image retain];

	[self setNeedsDisplay:YES];
}

- (NSColor *)textColor
{
	return _textColor;
}

- (void)setTextColor:(NSColor *)color
{
	if (color == _textColor) return;

	[_textColor release];
	_textColor = [color retain];

	[self setNeedsDisplay:YES];
}

- (NSShadow *)shadow
{
	return _shadow;
}

- (void)setShadow:(NSShadow *)aShadow
{
	if (aShadow == _shadow) return;

	[_shadow release];
	_shadow = [aShadow retain];

	[self setNeedsDisplay:YES];
}


#pragma mark -
#pragma mark boilerplate
@synthesize summaryString = _summaryString;

@end
