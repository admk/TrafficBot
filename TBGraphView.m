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

#pragma mark -
@interface GVPegView : NSView @end
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
@property (retain, nonatomic) NSImage *_imageRep;
@property (retain, nonatomic) NSDate *_mouseDate;

- (NSBezierPath *)_bezierPathForData;
- (NSImage *)_imageRepresenation;

- (void)_showDescriptionForDate:(NSDate *)date;
- (void)_dismissDescription;

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
	self._diffDict = nil;
	self._sortedDates = nil;
	self._firstDate = nil;
	self._lastDate = nil;
	[descriptionWindow release], descriptionWindow = nil;
	[_dataDict release], _dataDict = nil;
	[_pegView release], _pegView = nil;
	[_dateFormatter release], _dateFormatter = nil;
	[super dealloc];
}

#pragma mark -
#pragma mark drawRect
- (void)drawRect:(NSRect)dirtyRect {
	if (!self._imageRep) self._imageRep = [self _imageRepresenation];
	[self._imageRep drawInRect:self.bounds fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1];
}

#pragma mark -
#pragma mark notifications & events
- (void)viewWillStartLiveResize {
	[self _dismissDescription];
}
- (void)viewDidEndLiveResize {
	self._imageRep = [self _imageRepresenation];
	[self setNeedsDisplay:YES];
}
- (void)viewDidHide {
	[self _dismissDescription];
}
- (void)mouseDragged:(NSEvent *)theEvent {
	
	// ui behaviours
	[self _dismissDescription];
	if ([self.window respondsToSelector:@selector(setHasArrow:)]) {
		[(MAAttachedWindow *)self.window setHasArrow:NO];
	}
	[self.window setAlphaValue:.7];

	// frame calculations
	NSPoint originalMouseLocation = [self.window convertBaseToScreen:[theEvent locationInWindow]];
	NSRect originalFrame = [self.window frame];

	while (YES) {		
		
		NSEvent *newEvent = [self.window nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
		if ([newEvent type] == NSLeftMouseUp) {
			// user gave up left mouse
			[self.window orderOut:self];
			[self.window setAlphaValue:1];
			if ([self.window respondsToSelector:@selector(setHasArrow:)]) {
				[(MAAttachedWindow *)self.window setHasArrow:YES];
			}
			[delegate showDraggedWindowWithFrame:self.window.frame];
			return;
		}
		
		// still dragging
		NSPoint newMouseLocation = [self.window convertBaseToScreen:[newEvent locationInWindow]];
		NSRect newFrame = originalFrame;
		float deltaX = newMouseLocation.x - originalMouseLocation.x;
		float deltaY = newMouseLocation.y - originalMouseLocation.y;
		newFrame.origin.x += deltaX;
		newFrame.origin.y += deltaY;
		[self.window setFrame:newFrame display:YES animate:NO];
	}
}
- (void)mouseMoved:(NSEvent *)theEvent {
	if (HAS_NO_DATA) return;
	NSPoint point = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	if ([self mouse:point inRect:[self bounds]]) {
		self._mouseDate = [self _nearestDateForPoint:point];
		[self _showDescriptionForDate:self._mouseDate];
	}
	else {
		[self _dismissDescription];
	}
}
- (BOOL)acceptsFirstResponder {
	return YES;
}

#pragma mark -
#pragma mark accessors
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
	
	if (!IsEmpty(self._sortedDates)) {
		// dates
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
	}
	else {
		self._diffDict = [NSDictionary dictionary];
	}
	// update view
	[self _showDescriptionForDate:self._mouseDate];
	self._imageRep = [self _imageRepresenation];
	[self setNeedsDisplay:YES];
}

#pragma mark -
#pragma mark private
#pragma mark bezier path
- (NSBezierPath *)_bezierPathForData {
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path moveToPoint:[self _pointForDate:[self._sortedDates objectAtIndex:0]]];
	for (NSDate *date in self._sortedDates) {
		AKScopeAutoreleased();
		[path lineToPoint:[self _pointForDate:date]];
	}
	[path setLineWidth:2];
	[path setLineJoinStyle:NSRoundLineJoinStyle];
	return path;
}

#pragma mark drawing parts
- (void)_drawGrid {
	int yMax = 5;
	if (_yMax > 2) yMax = _yMax;
	// horizontal grid
	int incr = 2.5 * pow(10, (int)(log10f(yMax)-1));
	int yItr = 0;
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
		[[NSColor colorWithCalibratedWhite:1 alpha:.1*(yItr++%2)+.1] set];
		[yPath stroke];
	}
	// vertical grid
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
}
- (void)_drawNoData {
	NSPoint point = { self.bounds.size.width / 2 - 120, self.bounds.size.height / 2 };
	NSString *noDataString = @"No Data Available.";
	NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
								[NSFont fontWithName:@"Helvetica Light" size:32], NSFontAttributeName, 
								[NSColor colorWithCalibratedWhite:1 alpha:.3], NSForegroundColorAttributeName, nil];
	[noDataString drawAtPoint:point withAttributes:attributes];
}
- (void)_drawDates {
	if (!_dateFormatter) {
		_dateFormatter = [[NSDateFormatter alloc] init];
		[_dateFormatter setDateStyle:NSDateFormatterMediumStyle];
		[_dateFormatter setTimeStyle:NSDateFormatterNoStyle];
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
}
- (void)_drawGraph {
	// stroke
	NSBezierPath *path = [self _bezierPathForData];
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
- (NSImage *)_imageRepresenation {
	NSImage *image = [[[NSImage alloc] initWithSize:self.bounds.size] autorelease];
	[image lockFocus];
	[self _drawGrid];
	if (HAS_NO_DATA) {
		[self _drawNoData];
	}
	else {
		[self _drawDates];
		[self _drawGraph];
	}
	[image unlockFocus];
	return image;
}

#pragma mark descriptionWindow
- (void)_showDescriptionForDate:(NSDate *)date {
	if (!date) return;
	// points
	NSPoint viewPos = [self _pointForDate:date];
	NSPoint windowPos = [self convertPoint:viewPos toView:self.window.contentView];
	// peg
	NSRect pegRect = NSMakeRect(viewPos.x - 8, viewPos.y - 8, 16, 16);
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
	[descriptionWindow setDate:date];
	[descriptionWindow setData:[[self._diffDict objectForKey:date] floatValue]];
	// appear
	[descriptionWindow orderFront:self];
}
- (void)_dismissDescription {
	[descriptionWindow orderOut:self];
	[_pegView removeFromSuperview];
}

#pragma mark point query methods
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
@synthesize delegate;
@synthesize dataDict = _dataDict;
@synthesize _mouseDate, _imageRep, _sortedDates, _diffDict, _firstDate, _lastDate;
@end

