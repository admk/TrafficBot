//
//  TBGraphView.m
//  Graph View
//
//  Created by Adam Ko on 10/12/2010.
//  Copyright 2010 Imperial College. All rights reserved.
//

#define VIEW_INSET 20
#define MAX_ON_SCREEN_DATA 1440
#define MIN_DATA 2
#define HAS_NO_DATA [[self._diffDict allKeys] count] < MIN_DATA

#import "TBGraphView.h"
#import "GVDescriptionWindow.h"
#import "NSDate+AKMidnight.h"

@interface GVPegView : NSView
@end

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

#pragma mark -
@interface TBGraphView ()

@property (retain, nonatomic) NSDictionary *_diffDict;
@property (retain, nonatomic) NSArray *_sortedDates;
@property (retain, nonatomic) NSDate *_firstDate;
@property (retain, nonatomic) NSDate *_lastDate;
@property (retain, nonatomic) NSBezierPath *_path;

- (NSBezierPath *)_bezierPathForData;

- (NSPoint)_pointForDate:(NSDate *)date;
- (float)_horizontalPositionForDate:(NSDate *)date;
- (float)_verticalPositionForDate:(NSDate *)date;
- (NSDate *)_nearestDateForPoint:(NSPoint)point;

@end

#pragma mark -
@implementation TBGraphView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    return self;
}
- (void)dealloc {
	[descriptionWindow release], descriptionWindow = nil;
	[_dataDict release], _dataDict = nil;
	[_pegView release], _pegView = nil;
	[_dateFormatter release], _dateFormatter = nil;
	[super dealloc];
}

- (void)drawRect:(NSRect)dirtyRect {
	
	int yMax = 50000;
	if (_yMax > 2) yMax = _yMax;
	// grid
	int incr = 2.5 * pow(10, (int)(log10f(yMax)-1));
	for (float y = incr; y <= yMax; y += incr) {
		AKScopeAutoreleased();
		// path
		NSBezierPath *yPath = [NSBezierPath bezierPath];
		float yPos = y/yMax * (self.bounds.size.height - VIEW_INSET * 2) + VIEW_INSET;
		NSPoint yFrom = { VIEW_INSET, yPos };
		NSPoint yTo = { self.bounds.size.width - VIEW_INSET, yPos };
		[yPath moveToPoint:yFrom];
		[yPath lineToPoint:yTo];
		// stroke
		[[NSColor colorWithCalibratedWhite:1 alpha:.2] set];
		[yPath stroke];
	}
	
	if (HAS_NO_DATA) {
		NSPoint point = { self.bounds.size.width / 2 - 120, self.bounds.size.height / 2 };
		NSString *noDataString = @"No Data Available.";
		NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
									[NSFont fontWithName:@"Helvetica Light" size:32], NSFontAttributeName, 
									[NSColor colorWithCalibratedWhite:1 alpha:.3], NSForegroundColorAttributeName, nil];
		[noDataString drawAtPoint:point withAttributes:attributes];
		return;
	}
	
	// date
	if (!_dateFormatter) {
		_dateFormatter = [[NSDateFormatter alloc] init];
		[_dateFormatter setDateStyle:NSDateFormatterMediumStyle];
		[_dateFormatter setTimeStyle:NSDateFormatterNoStyle];
	}
	for (NSDate *date = [self._firstDate midnightTomorrow]; 
		 [date isLessThanOrEqualTo:self._lastDate]; 
		 date = [date midnightTomorrow]) {
		AKScopeAutoreleased();
		// point
		float xPos = [self _horizontalPositionForDate:date];
		NSPoint point = { xPos - 20, self.bounds.size.height - VIEW_INSET };
		// string
		NSString *dateString = [_dateFormatter stringFromDate:date];
		// draw
		NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
									[NSFont fontWithName:@"Helvetica Light" size:11], NSFontAttributeName, 
									[NSColor whiteColor], NSForegroundColorAttributeName, nil];
		[dateString drawAtPoint:point withAttributes:attributes];
	}
	for (NSDate *date = [self._firstDate nextHour]; 
		 [date isLessThanOrEqualTo:self._lastDate]; 
		 date = [date nextHour]) {
		AKScopeAutoreleased();
		// point
		float xPos = [self _horizontalPositionForDate:date];
		// grid path
		NSBezierPath *xPath = [NSBezierPath bezierPath];
		NSPoint xFrom = { xPos, VIEW_INSET };
		NSPoint xTo = { xPos, self.bounds.size.height - VIEW_INSET };
		[xPath moveToPoint:xFrom];
		[xPath lineToPoint:xTo];
		// stroke
		[[NSColor colorWithCalibratedWhite:1 alpha:.2] set];
		[xPath stroke];
	}
	
	// graph bezier
	if ([self inLiveResize])
		self._path = [self _bezierPathForData];
	// stroke
	NSBezierPath *path = [[self._path copy] autorelease];
	[[NSColor whiteColor] set];
	[path stroke];
	// fill
	NSColor *gradColor1 = [NSColor colorWithCalibratedRed:145.0/255 green:206.0/255 blue:230.0/255 alpha:.5];
	NSColor *gradColor2 = [NSColor colorWithCalibratedRed:145.0/255 green:206.0/255 blue:230.0/255 alpha:.1];
	NSGradient* gradient = [[[NSGradient alloc] initWithColorsAndLocations:
							 gradColor1, (CGFloat)0.0, gradColor2, (CGFloat)1.0, nil] autorelease];
	NSPoint endPoint = {self.bounds.size.width - VIEW_INSET, VIEW_INSET};
	[path lineToPoint:endPoint];
	[gradient drawInBezierPath:path angle:-90.0];
}

- (void)setDataDict:(NSDictionary *)dict {
	if (_dataDict == dict) return;
	[_dataDict release];
	_dataDict = [dict retain];
	
	// update dates
	NSMutableArray *sortedDates = [[[dict allKeys] mutableCopy] autorelease];
	[sortedDates sortUsingSelector:@selector(compare:)];
	if ([sortedDates count] > MAX_ON_SCREEN_DATA) {
		NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:
								NSMakeRange([sortedDates count] - MAX_ON_SCREEN_DATA, MAX_ON_SCREEN_DATA)];
		self._sortedDates = [sortedDates objectsAtIndexes:indexSet];
	}
	else {
		self._sortedDates = sortedDates;	
	}
	self._firstDate = [self._sortedDates objectAtIndex:0];
	self._lastDate = [self._sortedDates lastObject];
	_dateRange = [self._lastDate timeIntervalSinceDate:self._firstDate];
	
	// calculate speed
	NSMutableDictionary *diffDict = [NSMutableDictionary dictionaryWithCapacity:[dict count]];
	NSDate *prevDate = self._firstDate;
	for (NSDate *date in self._sortedDates) {
		AKScopeAutoreleased();
		if (prevDate != self._firstDate) {
			double data = [[dict objectForKey:date] doubleValue];
			NSTimeInterval ti = [date timeIntervalSinceDate:prevDate];
			double speed = data / ti;
			[diffDict setObject:[NSNumber numberWithDouble:speed] forKey:date];
		}
		prevDate = date;
	}
	self._diffDict = diffDict;
	
	// find max for graph
	_yMax = 0;
	for (NSDate *date in self._sortedDates) {
		AKScopeAutoreleased();
		double y = [[diffDict objectForKey:date] doubleValue];
		if (y > _yMax) _yMax = y;
	}
	
	// update path
	self._path = [self _bezierPathForData];
	[self setNeedsDisplay:YES];
}

#pragma mark -
#pragma mark events
- (void)mouseDragged:(NSEvent *)theEvent {
	
	[descriptionWindow orderOut:self];
	if ([self.window respondsToSelector:@selector(setHasArrow:)]) {
		[(MAAttachedWindow *)self.window setHasArrow:NO];
	}
	[self.window setAlphaValue:.7];

	while (YES) {
		
		NSEvent *newEvent = [self.window nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
		
		if ([newEvent type] == NSLeftMouseUp) {
			// user gave up left mouse
			[self.window orderOut:self];
			[self.window setAlphaValue:1];
			if ([self.window respondsToSelector:@selector(setHasArrow:)]) {
			[(MAAttachedWindow *)self.window setHasArrow:YES];
			}
			[controller showDraggedWindowWithFrame:self.window.frame];
			return;
		}
		
		// still dragging
		NSPoint windowOrigin = self.window.frame.origin;
		NSPoint newOrigin = NSMakePoint(windowOrigin.x + [newEvent deltaX], windowOrigin.y - [newEvent deltaY]);
		[self.window setFrameOrigin:newOrigin];
	}
}
- (void)mouseMoved:(NSEvent *)theEvent {
	if (HAS_NO_DATA) return;
	
	NSPoint mouse = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	NSDate *date = [self _nearestDateForPoint:mouse];
	_mouseViewPos = [self _pointForDate:date];
	NSPoint windowPos = [self convertPoint:_mouseViewPos toView:self.window.contentView];
	
	_mouseIsInside = [self mouse:mouse inRect:[self bounds]];
	if (_mouseIsInside) {
		// peg
		NSRect pegRect = NSMakeRect(_mouseViewPos.x - 8, _mouseViewPos.y - 8, 16, 16);
		if (!_pegView) {
			_pegView = [[GVPegView alloc] initWithFrame:pegRect];
		}
		_pegView.frame = pegRect;
		[self addSubview:_pegView];
		// window
		if (!descriptionWindow) {
			descriptionWindow = [[GVDescriptionWindow alloc] initWithPoint:windowPos inWindow:self.window];
		}
		[descriptionWindow setPoint:windowPos];
		// just appear
		[descriptionWindow setDate:date];
		[descriptionWindow setData:[[self._diffDict objectForKey:date] floatValue]];
		[descriptionWindow orderFront:self];
	}
	else {
		[_pegView removeFromSuperview];
		[descriptionWindow orderOut:self];
	}
}
- (BOOL)acceptsFirstResponder {
	return YES;
}

#pragma mark -
#pragma mark private
- (NSBezierPath *)_bezierPathForData {
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path moveToPoint:[self _pointForDate:[self._sortedDates objectAtIndex:0]]];
	for (NSDate *date in self._sortedDates) {
		AKScopeAutoreleased();
		[path lineToPoint:[self _pointForDate:date]];
	}
	[path setLineWidth:1.5];
	[path setLineJoinStyle:NSRoundLineJoinStyle];
	[path setFlatness:[self._sortedDates count]/20];
	return path;
}

- (NSPoint)_pointForDate:(NSDate *)date {
	NSPoint point;
	point.x = [self _horizontalPositionForDate:date];
	point.y = [self _verticalPositionForDate:date];
	return point;
}

- (float)_horizontalPositionForDate:(NSDate *)date {
	float propotion = [date timeIntervalSinceDate:self._firstDate] / _dateRange;
	return propotion * (self.bounds.size.width - VIEW_INSET * 2) + VIEW_INSET;
}

- (float)_verticalPositionForDate:(NSDate *)date {
	//ZAssert([[self._diffDict allKeys] containsObject:date], @"can't find value for date %@", date);
	float propotion = [[self._diffDict objectForKey:date] doubleValue] / _yMax;
	return propotion * (self.bounds.size.height - VIEW_INSET * 3) + VIEW_INSET;
}

- (NSDate *)_nearestDateForPoint:(NSPoint)point {
	float xProp = point.x / self.bounds.size.width;
	NSTimeInterval ti = xProp * _dateRange;
	NSDate *dateAtPoint = [self._firstDate dateByAddingTimeInterval:ti];
	for (NSDate *date in self._sortedDates) {
		if ([date isGreaterThan:dateAtPoint])
			return date;
	}
	return self._lastDate;
}
@synthesize controller;
@synthesize dataDict = _dataDict;
@synthesize _path, _sortedDates, _diffDict, _firstDate, _lastDate;
@end

