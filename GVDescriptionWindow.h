//
//  GVDescriptionWindow.h
//  Graph View
//
//  Created by Adam Ko on 11/12/2010.
//  Copyright 2010 Imperial College. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MAAttachedWindow.h"

@class DWView;
@interface GVDescriptionWindow : MAAttachedWindow {

	DWView *view;
	NSTextField *dateTextField;
	NSTextField *dataTextField;
@private
	NSDateFormatter *_dateFormatter;
	NSDate *_date;
	float _data;
	NSString *_dateString;
	NSString *_dataString;
}

@property (retain, nonatomic) NSDate *date;
@property (assign, nonatomic) float data;

- (id)initWithPoint:(NSPoint)point 
		   inWindow:(NSWindow *)window;

- (id)initWithPoint:(NSPoint)point 
		  inWindow:(NSWindow *)window 
			onSide:(MAWindowPosition)side 
		atDistance:(float)distance;

@end
