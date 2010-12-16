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

@class GVPegView;
@class GVDescriptionWindow;
@interface TBGraphView : NSView {

	__weak id<TBGraphViewDelegate> delegate;
	GVDescriptionWindow *descriptionWindow;	
@private
	NSDictionary	*_dataDict;
	float			_dateRange;
	float			_yMax;
	BOOL			_mouseIsInside;
	NSPoint			_mouseViewPos;
	GVPegView		*_pegView;
	NSDateFormatter *_dateFormatter;
}
@property (assign) id<TBGraphViewDelegate> delegate;
@property (retain, nonatomic) NSDictionary *dataDict;

@end
