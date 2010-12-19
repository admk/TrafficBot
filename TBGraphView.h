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
}
@property (assign) id<TBGraphViewDelegate> delegate;
@property (retain, nonatomic) NSDictionary *dataDict;

@end
