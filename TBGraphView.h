//
//  AKGraphView.h
//  Graph View
//
//  Created by Adam Ko on 10/12/2010.
//  Copyright 2010 Imperial College. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol TBGraphViewDelegate
@optional
- (void)showDraggedWindowWithFrame:(NSRect)frame;
@end

@class GVPegView, GVIndicatorView;
@class GVDescriptionWindow;
@interface TBGraphView : NSView <NSCoding> {

	__weak id<TBGraphViewDelegate> delegate;
	GVDescriptionWindow *descriptionWindow;	
@private
	NSDictionary	*_dataDict;
	float			_dateRange;
	float			_yMax;
	GVPegView		*_inPegView;
	GVPegView		*_outPegView;
	GVIndicatorView	*_indicatorView;
	NSDateFormatter *_dateFormatter;
	
	NSDictionary	*_inDiffDict;
	NSDictionary	*_outDiffDict;
	NSImage			*_imageRep;
	NSArray			*_sortedDates;
	NSDate			*_firstDate;
	NSDate			*_lastDate;
	NSDate			*_mouseDate;
	
	BOOL			_logScale;
}
@property (assign) id<TBGraphViewDelegate> delegate;
@property (retain, nonatomic) NSDictionary *dataDict;

@property (assign) BOOL logScale;

@end
