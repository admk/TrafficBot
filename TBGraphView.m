//
//  TBGraphView.m
//  Graph View
//
//  Created by Adam Ko on 10/12/2010.
//  Copyright 2010 Imperial College. All rights reserved.
//

#define VIEW_INSET 20.0f
#define MAX_ON_SCREEN_DATA 4800
#define MIN_DATA 3
#define HAS_NO_DATA [self._sortedDates count] < MIN_DATA

#import "TBGraphView.h"
#import "GVDescriptionWindow.h"
#import "GVViewCollection.h"
#import "NSDate+AKMidnight.h"
#import "AKBytesFormatter.h"

#pragma mark -
@interface TBGraphView ()

@property (retain, nonatomic) NSDictionary *_inDiffDict;
@property (retain, nonatomic) NSDictionary *_outDiffDict;
@property (retain, nonatomic) NSImage *_imageRep;
@property (retain, nonatomic) NSArray *_sortedDates;
@property (retain, nonatomic) NSDate *_firstDate;
@property (retain, nonatomic) NSDate *_lastDate;
@property (retain, nonatomic) NSDate *_mouseDate;

- (NSArray *)_bezierPathsWithDict:(NSDictionary *)dict;
- (NSImage *)_imageRepresenation;

- (void)_showDescriptionForDate:(NSDate *)date;
- (void)_dismissDescription;

- (NSPoint)_pointForDate:(NSDate *)date withDictionary:(NSDictionary *)dict;
- (float)_horizontalPositionForDate:(NSDate *)date;
- (float)_verticalPositionForDate:(NSDate *)date withDictionary:(NSDictionary *)dict;
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
	self._inDiffDict = nil;
	self._outDiffDict = nil;
	self._sortedDates = nil;
	self._firstDate = nil;
	self._lastDate = nil;
	[descriptionWindow release], descriptionWindow = nil;
	[_dataDict release], _dataDict = nil;
	[_indicatorView release], _indicatorView = nil;
	[_dateFormatter release], _dateFormatter = nil;
	[super dealloc];
}

#pragma mark -
#pragma mark NSCoding
- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [super initWithCoder:aDecoder];
	if (!self) return nil;
	self.dataDict = [aDecoder decodeObjectForKey:Property(dataDict)];
	return self;
}
- (void)encodeWithCoder:(NSCoder *)aCoder {
	[aCoder encodeObject:self.dataDict forKey:Property(dataDict)];
}

#pragma mark -
#pragma mark drawRect
- (void)drawRect:(NSRect)dirtyRect {
	if (!self._imageRep) self._imageRep = [self _imageRepresenation];
	NSRect boundsRect = NSInsetRect(self.bounds, VIEW_INSET, VIEW_INSET);
	NSRect imageRect = NSMakeRect(0, 0, self._imageRep.size.width, self._imageRep.size.height);
	imageRect = NSInsetRect(imageRect, VIEW_INSET, VIEW_INSET);
	[self._imageRep drawInRect:boundsRect fromRect:imageRect operation:NSCompositeSourceOver fraction:1];
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
		// wait for new events
		NSEvent *newEvent = [self.window nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
		if ([newEvent type] == NSLeftMouseUp) {
			// user gave up left mouse
			[self.window orderOut:self];
			[self.window setAlphaValue:1];
			if ([self.window respondsToSelector:@selector(setHasArrow:)]) {
				[(MAAttachedWindow *)self.window setHasArrow:YES];
			}
			if ([delegate respondsToSelector:@selector(showDraggedWindowWithFrame:)]) {
				[delegate showDraggedWindowWithFrame:self.window.frame];
			}
			return;
		}
		
		// still dragging
		NSPoint newMouseLocation = [self.window convertBaseToScreen:[newEvent locationInWindow]];
		NSRect newFrame = originalFrame;
		float deltaX = (float)(newMouseLocation.x - originalMouseLocation.x);
		float deltaY = (float)(newMouseLocation.y - originalMouseLocation.y);
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
		_dateRange = (float)[self._lastDate timeIntervalSinceDate:self._firstDate];
		// calculate speed
		NSMutableDictionary *inDiffDict = [NSMutableDictionary dictionaryWithCapacity:[dict count]];
		NSMutableDictionary *outDiffDict = [NSMutableDictionary dictionaryWithCapacity:[dict count]];
		NSDate *prevDate = self._firstDate;
		for (NSDate *date in self._sortedDates) {
			AKScopeAutoreleased();
			if (prevDate != self._firstDate) {
				double inData = [[[dict objectForKey:date] objectForKey:@"in"] doubleValue];
				double outData = [[[dict objectForKey:date] objectForKey:@"out"] doubleValue];
				NSTimeInterval ti = [date timeIntervalSinceDate:prevDate];
				double inSpeed = inData / ti;
				double outSpeed = outData / ti;
				[inDiffDict setObject:[NSNumber numberWithDouble:inSpeed] forKey:date];
				[outDiffDict setObject:[NSNumber numberWithDouble:outSpeed] forKey:date];
			}
			prevDate = date;
		}
		self._inDiffDict = inDiffDict;
		self._outDiffDict = outDiffDict;
		// find max for graph
		_yMax = 0;
		for (NSDate *date in self._sortedDates) {
			AKScopeAutoreleased();
			float inY = [[inDiffDict objectForKey:date] floatValue];
			float outY = [[outDiffDict objectForKey:date] floatValue];
			if (inY > _yMax) _yMax = inY;
			if (outY > _yMax) _yMax = outY;
		}
	}
	
	// update view
	if ([descriptionWindow isVisible]) {
		// refresh description window only if necessary
		[self _showDescriptionForDate:self._mouseDate];
	}
	self._imageRep = [self _imageRepresenation];
	[self setNeedsDisplay:YES];
}

#pragma mark -
#pragma mark private
#pragma mark bezier path
#define GV_BREAK_INTERVAL 3600
- (NSArray *)_bezierPathsWithDict:(NSDictionary *)dict {
	NSMutableArray *pathArray = [NSMutableArray array];
	NSBezierPath *path = nil;
	NSDate *prevDate = [NSDate distantPast];
	for (NSDate *date in self._sortedDates) {
		AKScopeAutoreleased();
		if ([date timeIntervalSinceDate:prevDate] <= GV_BREAK_INTERVAL) {
			[path lineToPoint:[self _pointForDate:date withDictionary:dict]];
		}
		else {
			path =  [NSBezierPath bezierPath];
			[pathArray addObject:path];
			[path setLineWidth:2];
			[path setLineJoinStyle:NSRoundLineJoinStyle];
			[path moveToPoint:[self _pointForDate:date withDictionary:dict]];
		}

		prevDate = date;
	}
	return pathArray;
}

#pragma mark drawing parts
- (void)_drawGrid {
	int yMax = 5;
	if (_yMax > 2) yMax = _yMax;
	// horizontal grid
	int incr = (int)(2.5 * pow(10, (int)(log10f(yMax)-1)));
	int yItr = 0;
	for (float y = incr; y <= yMax; y += incr) {
		AKScopeAutoreleased();
		// path
		NSBezierPath *yPath = [NSBezierPath bezierPath];
		float yPos = y/yMax * ((float)self.bounds.size.height - VIEW_INSET * 2) + VIEW_INSET;
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
- (void)_drawGraphWithPath:(NSBezierPath *)path withColor:(NSColor *)color {
	// stroke
	[color set];
	[path stroke];
	// gradient colors
	NSColor *color1 = [NSColor colorWithCalibratedRed:[color redComponent] 
												green:[color greenComponent] 
												 blue:[color blueComponent] 
												alpha:.5*[color alphaComponent]];
	NSColor *color2 = [NSColor colorWithCalibratedRed:[color redComponent] 
												green:[color greenComponent] 
												 blue:[color blueComponent] 
												alpha:.1*[color alphaComponent]];
	NSGradient *gradient = [[[NSGradient alloc] initWithStartingColor:color1 endingColor:color2] autorelease];
	// fill
	NSPoint endPoint = [path currentPoint];
	endPoint.y = VIEW_INSET;
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
		
		NSColor *inColor = [NSColor colorWithCalibratedRed:145.0/255 green:206.0/255 blue:230.0/255 alpha:.7];
		for (NSBezierPath *path in [self _bezierPathsWithDict:self._inDiffDict])
			[self _drawGraphWithPath:path withColor:inColor];
		
		NSColor *outColor = [NSColor colorWithCalibratedRed:1 green:172/255.0 blue:0 alpha:.7];
		for (NSBezierPath *path in [self _bezierPathsWithDict:self._outDiffDict])
			[self _drawGraphWithPath:path withColor:outColor];
	}
	[image unlockFocus];
	return image;
}

#pragma mark descriptionWindow
- (void)_showDescriptionForDate:(NSDate *)date {
	if (!date) return;
	// points
	float xPos = [self _horizontalPositionForDate:date];
	NSPoint viewPos = { xPos, self.bounds.size.height - VIEW_INSET };
	NSPoint windowPos = viewPos;
	windowPos.x += self.window.frame.origin.x;
	windowPos.y += self.window.frame.origin.y;
	// indicator
	NSRect indicatorRect = NSMakeRect( viewPos.x - 10, VIEW_INSET, 20, self.bounds.size.height - VIEW_INSET);
	if (!_indicatorView) {
		_indicatorView = [[GVIndicatorView alloc] initWithFrame:indicatorRect];
	}
	_indicatorView.frame = indicatorRect;
	[self addSubview:_indicatorView];
	// peg
	NSPoint inPegPoint = [self _pointForDate:date withDictionary:self._inDiffDict];
	NSPoint outPegPoint = [self _pointForDate:date withDictionary:self._outDiffDict];
	NSRect inPegRect = NSMakeRect(inPegPoint.x - 8, inPegPoint.y - 8, 16, 16);
	NSRect outPegRect = NSMakeRect(outPegPoint.x - 8, outPegPoint.y - 8, 16, 16);
	if (!_inPegView) {
		_inPegView = [[GVPegView alloc] initWithFrame:inPegRect];
	}
	if (!_outPegView) {
		_outPegView = [[GVPegView alloc] initWithFrame:outPegRect];
	}
	_inPegView.frame = inPegRect;
	_outPegView.frame = outPegRect;
	[self addSubview:_inPegView];
	[self addSubview:_outPegView];
	// description string
	NSString *inString = [AKBytesFormatter convertBytesWithNumber:[self._inDiffDict objectForKey:date] decimals:YES];
	NSString *outString = [AKBytesFormatter convertBytesWithNumber:[self._outDiffDict objectForKey:date] decimals:YES];
	NSString *detailString = [NSString stringWithFormat:@"In: %@/s, Out: %@/s", inString, outString];
	// window
	if (!descriptionWindow) {
		descriptionWindow = [[GVDescriptionWindow alloc] initWithPoint:windowPos inWindow:nil];
	}
	[descriptionWindow setPoint:windowPos];
	[descriptionWindow updateViewWithDate:date detail:detailString];
	// appear
	[descriptionWindow orderFront:self];
}
- (void)_dismissDescription {
	[descriptionWindow orderOut:self];
	[_inPegView removeFromSuperview];
	[_outPegView removeFromSuperview];
	[_indicatorView removeFromSuperview];
}

#pragma mark point query methods
- (NSPoint)_pointForDate:(NSDate *)date withDictionary:(NSDictionary *)dict{ 
	return (NSPoint) {
		[self _horizontalPositionForDate:date],
		[self _verticalPositionForDate:date withDictionary:dict]
	};
}
- (float)_horizontalPositionForDate:(NSDate *)date {
	float propotion = (float)[date timeIntervalSinceDate:self._firstDate] / _dateRange;
	return propotion * ((float)self.bounds.size.width - VIEW_INSET * 2) + VIEW_INSET;
}
- (float)_verticalPositionForDate:(NSDate *)date withDictionary:(NSDictionary *)dict {
	float propotion = [[dict objectForKey:date] floatValue] / _yMax;
	return propotion * ((float)self.bounds.size.height - VIEW_INSET * 3) + VIEW_INSET;
}
- (NSDate *)_nearestDateForPoint:(NSPoint)point {
	float xProp = (float)(point.x / self.bounds.size.width);
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
@synthesize _inDiffDict, _outDiffDict;
@synthesize _imageRep;
@synthesize _mouseDate, _sortedDates, _firstDate, _lastDate;
@end

