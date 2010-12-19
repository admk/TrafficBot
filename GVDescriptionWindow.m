//
//  GVDescriptionWindow.m
//  Graph View
//
//  Created by Adam Ko on 11/12/2010.
//  Copyright 2010 Imperial College. All rights reserved.
//

#import "GVDescriptionWindow.h"

#define VIEW_CORNER_RADIUS ((float)5.0)
#define VIEW_GRADIENT_COLOR_1 [NSColor colorWithCalibratedRed:100.0/255 green:200.0/255 blue:1 alpha:1]
#define VIEW_GRADIENT_COLOR_2 [NSColor colorWithCalibratedRed:0 green:100.0/255 blue:171.0/255 alpha:1]

#pragma mark -
#pragma mark MAAttachedWindow private methods
@interface MAAttachedWindow (MAPrivateMethods)
- (void)_redisplay;
@end

#pragma mark -
#pragma mark description window content view
@interface DWView : NSView
@end
@implementation DWView : NSView
- (void)drawRect:(NSRect)dirtyRect {
	NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:VIEW_CORNER_RADIUS yRadius:VIEW_CORNER_RADIUS];
	NSGradient* gradient = [[[NSGradient alloc] initWithColorsAndLocations:
							 VIEW_GRADIENT_COLOR_1, (CGFloat)0.0, VIEW_GRADIENT_COLOR_2, (CGFloat)1.0, nil] autorelease];
	[gradient drawInBezierPath:path angle:-90];
}
@end

#pragma mark -
#pragma mark private methods
@interface GVDescriptionWindow ()
<<<<<<< HEAD
@property (retain, nonatomic) NSString *_dateString;
@property (retain, nonatomic) NSString *_dataString;
- (void)_updateViewSize;
- (float)_widthOfString:(NSString *)string withFont:(NSFont *)font;
=======
- (CGFloat)_widthOfString:(NSString *)string withFont:(NSFont *)font;
>>>>>>> Preliminary in/out graph view.
- (NSTextField *)_newTextFieldWithFrame:(NSRect)frameRect;
@end

#pragma mark -
@implementation GVDescriptionWindow

- (id)initWithPoint:(NSPoint)point 
		   inWindow:(NSWindow *)window {
	return [self initWithPoint:point inWindow:window onSide:MAPositionTop atDistance:10];
}
- (id)initWithPoint:(NSPoint)point 
		   inWindow:(NSWindow *)window 
			 onSide:(MAWindowPosition)side 
		 atDistance:(float)distance {
	
	view = [[DWView alloc] initWithFrame:NSMakeRect(0, 0, 50, 35)];
	dateTextField = [self _newTextFieldWithFrame:NSMakeRect(0, 21, 50, 11)];
	detailTextField = [self _newTextFieldWithFrame:NSMakeRect(0, 6, 50, 15)];
	[detailTextField setFont:[NSFont fontWithName:@"Helvetica" size:14]];
	[view addSubview:dateTextField], [view addSubview:detailTextField];
	
	[super initWithView:view attachedToPoint:point inWindow:window onSide:side atDistance:distance];
	if (!self) {
		[self dealloc];
		return nil;
	}
	
	[self setBackgroundColor:VIEW_GRADIENT_COLOR_2];
	[self setBorderWidth:0];
	[self setBorderColor:[NSColor blackColor]];
	[self setArrowBaseWidth:10];
	[self setArrowHeight:6];
	[self setViewMargin:0];
	[self setLevel:NSStatusWindowLevel];
	[self setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
	[self setIgnoresMouseEvents:YES];
	
	return self;
}
- (void)dealloc {
	[_dateFormatter release], _dateFormatter = nil;
	[dateTextField release], dateTextField = nil;
	[detailTextField release], detailTextField = nil;
	[view release], view = nil;
	
	[super dealloc];
}

#pragma mark -
#pragma mark view update
- (void)updateViewWithDate:(NSDate *)date detail:(NSString *)detailString {
	// update text fields
	if (!_dateFormatter) {
		_dateFormatter = [[NSDateFormatter alloc] init];
		[_dateFormatter setDateStyle:NSDateFormatterNoStyle];
		[_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	}
<<<<<<< HEAD
	self._dateString = [_dateFormatter stringFromDate:_date];
	
	// set text label
	[dateTextField setTitleWithMnemonic:self._dateString];
}
- (void)setData:(float)newData {
	if (_data == newData) return;
	_data = newData;

	NSNumber *number = [NSNumber numberWithFloat:newData];
	self._dataString = [AKBytesFormatter convertBytesWithNumber:number];
	self._dataString = [self._dataString stringByAppendingString:@"/s"];
	// set text label
	[dataTextField setTitleWithMnemonic:self._dataString];
	
	[self _updateViewSize];
}

#pragma mark -
#pragma mark private
- (void)_updateViewSize {
	
	float dateWidth = [self _widthOfString:self._dateString withFont:[NSFont fontWithName:@"Helvetica" size:12.0f]];
	float dataWidth = [self _widthOfString:self._dataString withFont:[NSFont fontWithName:@"Helvetica" size:14]];
=======
	NSString *dateString = [_dateFormatter stringFromDate:date];
	[dateTextField setTitleWithMnemonic:dateString];
	[detailTextField setTitleWithMnemonic:detailString];
	// update view size
	float dateWidth = [self _widthOfString:dateString withFont:[NSFont fontWithName:@"Helvetica" size:12]];
	float dataWidth = [self _widthOfString:detailString withFont:[NSFont fontWithName:@"Helvetica" size:14]];
>>>>>>> Preliminary in/out graph view.
	float maxWidth;
	if (dateWidth > dataWidth) maxWidth = dateWidth;
	else maxWidth = dataWidth;
	NSRect rect = view.frame;
	rect.size.width = maxWidth + 10;
	[view setFrame:rect];
	[super _redisplay];
}
<<<<<<< HEAD
- (float)_widthOfString:(NSString *)string withFont:(NSFont *)font {
=======

#pragma mark -
#pragma mark private
- (CGFloat)_widthOfString:(NSString *)string withFont:(NSFont *)font {
>>>>>>> Preliminary in/out graph view.
	NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, nil];
	NSAttributedString *aString = [[[NSAttributedString alloc] initWithString:string attributes:attributes] autorelease];
	return (float)aString.size.width;
}

- (NSTextField *)_newTextFieldWithFrame:(NSRect)frameRect {
	NSTextField *textField = [[NSTextField alloc] initWithFrame:frameRect];
	[textField setFont:[NSFont fontWithName:@"Helvetica" size:11]];
	[textField setAlignment:NSCenterTextAlignment];
	[textField setTextColor:[NSColor blackColor]];
	[textField setDrawsBackground:NO];
	[textField setBezeled:NO];
	[textField setEditable:NO];	
	[textField setAutoresizingMask:~NSViewNotSizable];
	[[textField cell] setBackgroundStyle:NSBackgroundStyleRaised];
	return textField;
}

@end
